require 'active_support/core_ext/array'
require 'json'

class Plutil
  module JSON
    def self.load(plist)
      Plutil.convert plist, to: :json do |converted_io|
        ::JSON.load(converted_io)
      end
    end

    def self.call(*args)
      load(*args)
    end

    def self.dump(object, options = {})
      Plutil.convert :stdin, options.reverse_merge(to: :xml) do |io|
        io.write ::JSON.dump(object.to_h)
        io.close_write
        io.read
      end
    end
  end

  # Also aliased as `Plutil.plutil`
  # Usage:
  #
  #   Plutil.(:remove, "keypath", file: plist, &:read)
  #   Plutil.(:extract, "keypath", :json, file: plist, &:read)
  #
  def self.call(*args, &block)
    new(*args).execute(&block)
  end

  # Usage:
  #
  #   Plutil.insert('keypath', "-bool", "YES", file: plist, &:read)
  #
  class << self
    alias_method :plutil, :call

    [:remove, :extract, :insert].each do |command|
      define_method(command) {|*args, &block| plutil(command, *args, &block) }
    end
  end

  # Usage:
  #
  #   Plutil.convert plist, to: 'json' do |converted_io|
  #     JSON.load(converted_io)
  #   end
  #
  def self.convert(path, to: :json, &block)
    to = "xml1" if to.to_s == 'xml'
    plutil(:convert, to, out: :stdin, file: path.to_s, &block)
  end

  # Usage:
  #
  #   Plutil.replace(plist, 'name', data, as: 'xml', &:read)
  #
  def self.replace(path, keypath, data, as: :xml, &block)
    plutil(:replace, keypath, "-#{as}", data, file: path.to_s, &block)
  end

  # Shorthand to `Plutil::JSON.load(plist)`
  def self.load_json(*args)
    Plutil::JSON.load(*args)
  end

  def self.dump_json(*args)
    Plutil::JSON.dump(*args)
  end

  def initialize(*args)
    options = args.extract_options!
    @command, *@args = *args
    @in, @out, @mode = *options.values_at(:in, :out, :mode)
    @in   ||= options[:file]
    @mode ||= auto_mode
  end

  def execute(&block)
    io = IO.popen(cmd, @mode)
    block.call(io)
  ensure
    io.close if io && !io.closed?
  end

  def output_args; @out && ['-o', normalize_io_arg(@out)]; end
  def input_args; @in && ['--', normalize_io_arg(@in)]; end
  def stdin?; @in.to_s == 'stdin'; end

  private
  def cmd
    ['plutil', "-#@command"] + Array(@args.map(&:to_s)) + Array(output_args) + Array(input_args)
  end

  def normalize_io_arg(io)
    case io.to_s
    when 'stdin', 'stdout' then '-'
    else io
    end
  end

  def auto_mode
    case @command
    when :convert then stdin? ? 'w+' : 'r'
    when :replace then 'w+'
    else 'r'
    end
  end
end
