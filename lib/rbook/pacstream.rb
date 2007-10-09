$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../")

require 'net/ftp'
require 'tempfile'

module RBook

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
      if args[0][:username].nil? && args[0][:password].nil?
        raise ArgumentError, 'username and password must be specified'
      end

      unless FILE_EXTENSIONS.include?(type)
        raise ArgumentError, 'unrecognised type'
      end    

      server = args[0][:servername] || "pacstream.tedis.com.au"

      begin
        transaction_complete = false
        Net::FTP.open(server) do |ftp|
          
            file_regexp = Regexp.new(".*\.#{FILE_EXTENSIONS[type]}$", Regexp::IGNORECASE)
            ftp.login(args[0][:username].to_s, args[0][:password].to_s)
            ftp.chdir("outgoing/")
            ftp.nlst.each do |file|
              if file.match(file_regexp)
                tempfile = Tempfile.new("pacstream")
                tempfile.close
                ftp.getbinaryfile(file, tempfile.path)
                yield File.read(tempfile.path)
                tempfile.unlink
              end
            end
            transaction_complete = true
            #ftp.quit
        end
      rescue EOFError
        raise "Connection terminated by remote server" unless transaction_complete
      rescue Net::FTPPermError
        raise "Error while communicating with the pacstream server"
      end
    end
  end
end
