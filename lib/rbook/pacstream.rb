$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../")

require 'net/ftp'
require 'tempfile'

module RBook

  # an error indicating pacstream authentication issues
  class PacstreamAuthError < RuntimeError; end

  # an error indocating a problem with executing a pacstream command
  class PacstreamCommandError < RuntimeError; end

  # an error indicating a problem connecting to the pacstream server
  class PacstreamConnectionError < RuntimeError; end

  # Ruby class for sending and retrieving electronic orders
  # via pacstream, a service run by the ECN Group 
  # (http://www.ecngroup.com.au/)
  #
  # = Basic Usage
  #
  #  pac = RBook::Pacstream.new(:username => "myusername", :password => "mypass")
  #  pac.login
  #  pac.get(:orders) do |order|
  #    puts order
  #  end
  #  pac.get(:poacks) do |poa|
  #    puts poa
  #  end
  #  pac.put(:order, 1000, order_text)
  #  pac.quit
  #
  # = Alternative Usage
  #  RBook::Pacstream.open(:username => "myusername", :password => "mypass") do |pac|
  #    pac.get(:orders) do |order|
  #      puts order
  #    end
  #    pac.put(:order, 1000, order_text)
  #  end
  class Pacstream
      
    FILE_EXTENSIONS = { :orders => "ORD", :invoices => "ASN", :poacks => "POA" }
    FILE_EXTENSIONS_SINGULAR = { :order => "ORD", :invoice => "ASN", :poack => "POA" }

    def initialize(*args)
      if args[0][:username].nil? && args[0][:password].nil?
        raise ArgumentError, 'username and password must be specified'
      end

      @server   = args[0][:servername].to_s || "pacstream.tedis.com.au"
      @username = args[0][:username].to_s
      @password = args[0][:password].to_s
    end

    # download all documents of a particular type from the pacstream server
    #
    #   pac.get(:orders) do |order|
    #     puts order
    #   end
    #
    # WARNING: as soon as you download the order, the file is deleted from the server
    #          and cannot be retrieved again
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

    # logs into to the pacstream server. Can raise several exceptions
    # RBook::PacstreamConnectionError - Can't connect to server
    # RBook::PacstreamAuthError - Invalid username or password
    def login
      begin
        @ftp = Net::FTP.open(@server)
        @ftp.login(@username, @password)
      rescue Net::FTPPermError => e
        raise PacstreamAuthError, e.message
      rescue SocketError => e
        raise PacstreamConnectionError, e.message
      rescue Errno::ECONNREFUSED => e
        raise PacstreamConnectionError, e.message
      end
    end

    # upload a file to the pacstream server
    # type    - :order, invoice or :poack
    # ref     - a reference number, used to name the file
    # content - the content to upload
    def put(type, ref, content)
      raise PacstreamCommandError, "No current session open" unless @ftp
      raise ArgumentError, 'unrecognised type' unless FILE_EXTENSIONS_SINGULAR.include?(type.to_sym)

      remote_filename = "#{ref}.#{FILE_EXTENSIONS_SINGULAR[type.to_sym]}"
      @ftp.chdir("incoming/")

      tempfile = Tempfile.new("pacstream")
      tempfile.write(content)
      tempfile.close

      @ftp.putbinaryfile(tempfile.path, remote_filename)

      tempfile.unlink

      @ftp.chdir("..")
    end

    # logout from the pacstream server
    def quit
      raise PacstreamCommandError, "No current session open" unless @ftp

      begin
        @ftp.quit
      rescue Exception => e
        # do nothing. Sometimes the server closes the connection and causes
        # the ftp lib to freak out a little
      end
    end

    # Deprecated way to download files from the pacstream server
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

    # Alternative, block syntax. See notes at the top of the class for usage
    def self.open(*args, &block)
      pac = RBook::Pacstream.new(args[0])
      pac.login
      yield pac
      pac.quit
    end
  end
end
