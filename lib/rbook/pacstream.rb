$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../")

require 'net/ftp'
require 'tempfile'

module RBook

  class PacstreamAuthError < RuntimeError; end
  class PacstreamCommandError < RuntimeError; end

  # Ruby class for sending and retrieving electronic orders
  # via pacstream, a service run by the ECN Group 
  # (http://www.ecngroup.com.au/)
  #
  # = Basic Usage
  #
  #  RBook::Pacstream.get(:orders, :username => "myusername", :password => "mypass") do |order|
  #    puts order
  #  end
  class Pacstream
      
    FILE_EXTENSIONS = { :orders => "ORD", :invoices => "ASN", :poacks => "POA" }

    def initialize(*args)
      if args[0][:username].nil? && args[0][:password].nil?
        raise ArgumentError, 'username and password must be specified'
      end

      @server   = args[0][:servername].to_s || "pacstream.tedis.com.au"
      @username = args[0][:username].to_s
      @password = args[0][:password].to_s
    end

    def get(type, &block)
      raise PacstreamCommandError, "No current session open" unless @ftp
      raise ArgumentError, 'unrecognised type' unless FILE_EXTENSIONS.include?(type.to_sym)

      # determine the filename pattern we're searching for
      file_regexp = Regexp.new(".*\.#{FILE_EXTENSIONS[type.to_sym]}$", Regexp::IGNORECASE)
      @ftp.chdir("outgoing/")

      # loop over each file in the outgoing dir and check if it matches the file type we're after
      @ftp.nlst.each do |file|
        if file.match(file_regexp)

          # for all matching files, download to a temp file, return the contents, then delete the file
          tempfile = Tempfile.new("pacstream")
          tempfile.close
          @ftp.getbinaryfile(file, tempfile.path)
          yield File.read(tempfile.path)
          tempfile.unlink
        end
      end

      @ftp.chdir("..")
    end

    def login
      @ftp = Net::FTP.open(@server)
      @ftp.login(@username, @password)
    end

    def put(type, ref, content)
      raise PacstreamCommandError, "No current session open" unless @ftp
      raise ArgumentError, 'unrecognised type' unless FILE_EXTENSIONS.include?(type.to_sym)

      remote_filename = "#{ref}.#{FILE_EXTENSIONS[type.to_sym]}"
      @ftp.chdir("incoming/")

      tempfile = Tempfile.new("pacstream")
      tempfile.write(content)
      tempfile.close

      @ftp.putbinaryfile(tempfile.path, remote_filename)

      tempfile.unlink

      @ftp.chdir("..")
    end

    def quit
      raise PacstreamCommandError, "No current session open" unless @ftp
      @ftp.quit
    end

    # Iterate over each document waiting on the pacstream server, returning
    # it as a string
    #
    # Document types available:
    # 
    # Purchase Orders (:orders)
    # Purchase Order Acknowledgements (:poacks)
    # Invoices (:invoices)
    #
    #  RBook::Pacstream.get(:orders, :username => "myusername", :password => "mypass") do |order|
    #    puts order
    #  end
    def self.get(type = :orders, *args, &block)
      pac = RBook::Pacstream.new(args[0])
      pac.login
      pac.get(type) do |content|
        yield content
      end
      pac.quit
    end
  end
end
