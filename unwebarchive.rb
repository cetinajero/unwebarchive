#!/usr/bin/env ruby
#
# Mac OS X webarchive is a binary format of a plist file. You can extract the contents manually:
#  1. convert the plist file into XML by "plutil -convert xml1 file.webarchive"
#  2. parse the resulted XML file by some XML parser
#  3. decode "WebResourceData" by Base64.decode64(data) in each key
#  4. save the decoded content into a file indicated by "WebResourceData"
# Thankfully, the plist library can take care of annoying steps 2 and 3.
#
# Preparation:
#  % gem install plist
#
# Usage:
#  % unwebarchive.rb filename.webarchive
#
# Result:
#  You'll find the extracted contents under the 'filename/' directory.
#

require 'rubygems'
require 'fileutils'
require 'plist'
require_relative 'lib/plutil'

webarchive = ARGV.shift
exportdir = File.basename(webarchive, ".webarchive")

class UnWebarchive

  def initialize(webarchive, exportdir)
    @file = webarchive
    @dir  = exportdir

    prepare_exportdir
    parse_webarchive
  end

  def prepare_exportdir
    if File.exists?(@dir)
      print "Override existing export directory '#{@dir}' [Yes/No]? "
      exit 1 unless gets.chomp[/^y(es)?$/i]
    end
    FileUtils.mkdir_p(@dir)
    FileUtils.cp(@file, @dir)
  end

  def parse_webarchive
    FileUtils.cd(@dir) do
      system("plutil -convert xml1 #{@file}")
      plist = Plist.parse_xml(File.read(@file))
      file = plist["WebMainResource"]["WebResourceURL"]
      data = plist["WebMainResource"]["WebResourceData"].read
      data.gsub!(/file:\/\/\//, './')
      export('file:///index.html', data)
      plist["WebSubresources"].each do |res|
        file = res["WebResourceURL"]
        data = res["WebResourceData"].read
        export(file, data)
      end
    end
  end

  def export(resource_uri, resource_data)
    if resource_uri[/^file:/]
      name = resource_uri.sub('file:///', '')
      write_file(name, resource_data)
    elsif resource_uri[/^http/]
      name = resource_uri.sub(/^http.*\:\/\//, '')
      write_file(name, resource_data)
    else
      puts "[ERR] skipping #{resource_uri}"
    end
  end

  def write_file(name, resource_data)
    puts "[INFO] Writing '#{@dir}/#{name}' ..."
    dirname = File.dirname(name)
    unless File.directory?(dirname)
      FileUtils.mkdir_p(dirname)
    end
    File.open(name, "w") do |file|
      file.print fix_paths(name, resource_data)
    end
  end
end

  def fix_paths(name, resource_data)
    exempted_formats = [".png", ".jpg", ".gif", ".svg", ".woff", ".woff2", ".aspx", ".js"]
    if (File.extname(name.split('?').first) == '.html')
      puts "[INFO] Fixing paths on '#{@dir}/#{name}' ..."
      resource_data.gsub!(/href="[^=]*http[^=]*:\/\//, 'href="')
      resource_data.gsub!(/src="[^=]*http[^=]*:\/\//, 'src="')
    elsif (File.extname(name.split('?').first) == '.css')
      resource_data.gsub!(/url\('[^\)]*http[^\)]*:\/\//, "url('../../")
      resource_data.gsub!(/url\([^'\)]*http[^'\)]*:\/\//, "url(../../")
    elsif (exempted_formats.include? File.extname(name.split('?').first))
      puts "[INFO] Exempted path analisis on '#{@dir}/#{name}' ..."
    else
      puts "[WARN] Avoiding paths analisis on '#{@dir}/#{name}' ..."
    end
    return resource_data
  end

UnWebarchive.new(webarchive, exportdir)
