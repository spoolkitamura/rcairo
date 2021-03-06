#!/usr/bin/env ruby
# vim: filetype=ruby:expandtab:shiftwidth=2:tabstop=8:softtabstop=2 :

require 'pathname'
require 'English'
require 'mkmf'
require 'fileutils'

require "pkg-config"
require "native-package-installer"

checking_for(checking_message("GCC")) do
  if macro_defined?("__GNUC__", "")
    $CFLAGS += ' -Wall'
    true
  else
    false
  end
end

package = "cairo"
module_name = "cairo"
major, minor, micro = 1, 2, 0

base_dir = Pathname(__FILE__).dirname.parent.parent
checking_for(checking_message("Win32 OS")) do
  case RUBY_PLATFORM
  when /mingw|mswin32/
    $defs << "-DRUBY_CAIRO_PLATFORM_WIN32"
    import_library_name = "libruby-#{module_name}.a"
    $DLDFLAGS << " -Wl,--out-implib=#{import_library_name}"
    $cleanfiles << import_library_name
    binary_base_dir = base_dir + "vendor" + "local"
    if with_config('vendor-override', binary_base_dir.exist?)
      $CFLAGS += " -I#{binary_base_dir}/include"
      pkg_config_dir = binary_base_dir + "lib" + "pkgconfig"
      PKGConfig.add_path(pkg_config_dir.to_s)
      PKGConfig.set_override_variable("prefix", binary_base_dir.to_s)
    end
    true
  else
    false
  end
end

def required_pkg_config_package(package_info, native_package_info=nil)
  if package_info.is_a?(Array)
    required_package_info = package_info
  else
    required_package_info = [package_info]
  end
  return true if PKGConfig.have_package(*required_package_info)

  native_package_info ||= {}
  return false unless NativePackageInstaller.install(native_package_info)

  PKGConfig.have_package(*required_package_info)
end

unless required_pkg_config_package([package, major, minor, micro],
                                   :debian => "libcairo2-dev",
                                   :redhat => "cairo-devel",
                                   :homebrew => "cairo",
                                   :macports => "cairo",
                                   :msys2 => "cairo")
  exit(false)
end

PKGConfig.have_package("cairo-ft")

checking_for(checking_message("Mac OS X")) do
  case RUBY_PLATFORM
  when /darwin/
    if have_macro("CAIRO_HAS_QUARTZ_SURFACE", ["cairo.h"])
      checking_for("RubyCocoa") do
        begin
          require "osx/cocoa"
          $defs << "-DHAVE_RUBY_COCOA"
          $DLDFLAGS << " -Wl,-framework,RubyCocoa"
          true
        rescue LoadError
          false
        end
      end
    end
    true
  else
    false
  end
end

$defs << "-DRB_CAIRO_COMPILATION"

have_header("ruby/st.h") unless have_macro("HAVE_RUBY_ST_H", "ruby.h")
have_header("ruby/io.h") unless have_macro("HAVE_RUBY_IO_H", "ruby.h")
have_func("rb_errinfo", "ruby.h")
have_func("rb_gc_adjust_memory_usage", "ruby.h")
have_type("enum ruby_value_type", "ruby.h")

create_makefile(module_name)
