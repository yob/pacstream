$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../vendor')

require 'rbook/pacstream'
require 'not_a_mock'
require 'rubygems'
require 'spec'

Spec::Runner.configure do |config|
    config.mock_with NotAMock::RspecMockFrameworkAdapter
end

context "The pacstream class" do

  setup do
    @options = {:servername => "127.0.0.1",
                :username   => "test",
                :password   => "pass"}

  end

  specify "should open and close an ftp connection when login and logout are called in the right order" do
    # prevent a real ftp session from being opened. If the lib attempts to open
    # a connection, just return a stubbed class
    ftp = Net::FTP.stub_instance(:login => true, :quit => true)
    Net::FTP.stub_method(:new => ftp, :open => ftp)

    pac = RBook::Pacstream.new(@options)
    pac.login
    pac.quit

    Net::FTP.should have_received(:open).once.with(@options[:servername])
    ftp.should have_received(:login).once.with(@options[:username], @options[:password])
    ftp.should have_received(:quit).once.without_args
  end

  specify "should return the contents of a invoice when looping over all available invoices's" do
    # prevent a real ftp session from being opened. If the lib attempts to open
    # a connection, just return a stubbed class
    # this stub will allow the user to call chdir, and pretends that there is a single invoice available
    # for download
    ftp = Net::FTP.stub_instance(:login => true, :chdir => true, :nlst => ["1.ASN"], :getbinaryfile => true, :quit => true)
    Net::FTP.stub_method(:new => ftp, :open => ftp)
    File.stub_method(:read => "this is an invoice")

    pac = RBook::Pacstream.new(@options)
    pac.login
    pac.get(:invoices) do |ord|
      ord.should eql("this is an invoice")
    end
    pac.quit

    ftp.should have_received(:chdir).twice
    ftp.should have_received(:nlst).once.without_args
    ftp.should have_received(:getbinaryfile).once
  end

  specify "should return the contents of an order when looping over all available orders" do
    # prevent a real ftp session from being opened. If the lib attempts to open
    # a connection, just return a stubbed class
    # this stub will allow the user to call chdir, and rpretends that there is a single order available
    # for download
    ftp = Net::FTP.stub_instance(:login => true, :chdir => true, :nlst => ["1.ORD"], :getbinaryfile => true, :quit => true)
    Net::FTP.stub_method(:new => ftp, :open => ftp)
    File.stub_method(:read => "this is an order")

    pac = RBook::Pacstream.new(@options)
    pac.login
    pac.get(:orders) do |ord|
      ord.should eql("this is an order")
    end
    pac.quit

    ftp.should have_received(:chdir).twice
    ftp.should have_received(:nlst).once.without_args
    ftp.should have_received(:getbinaryfile).once
  end

  specify "should return an array of waiting files on request, and not attempt to download them" do
    # prevent a real ftp session from being opened. If the lib attempts to open
    # a connection, just return a stubbed class
    # this stub will allow the user to call chdir, and pretends that there are two orders available
    # for download
    ftp = Net::FTP.stub_instance(:login => true, :chdir => true, :nlst => ["1.ORD","2.ORD"], :getbinaryfile => true, :quit => true)
    Net::FTP.stub_method(:new => ftp, :open => ftp)

    pac = RBook::Pacstream.new(@options)
    pac.login
    pac.list(:orders).should eql(["1.ORD","2.ORD"])
    pac.quit

    ftp.should have_received(:chdir).twice
    ftp.should have_received(:nlst).once.without_args
    ftp.should_not have_received(:getbinaryfile)
  end

  specify "should return the contents of a POA when looping over all available poa's" do
    # prevent a real ftp session from being opened. If the lib attempts to open
    # a connection, just return a stubbed class
    # this stub will allow the user to call chdir, and pretends that there is a single poa available
    # for download
    ftp = Net::FTP.stub_instance(:login => true, :chdir => true, :nlst => ["1.POA"], :getbinaryfile => true, :quit => true)
    Net::FTP.stub_method(:new => ftp, :open => ftp)
    File.stub_method(:read => "this is a poa")

    pac = RBook::Pacstream.new(@options)
    pac.login
    pac.get(:poacks) do |ord|
      ord.should eql("this is a poa")
    end
    pac.quit

    ftp.should have_received(:chdir).twice
    ftp.should have_received(:nlst).once.without_args
    ftp.should have_received(:getbinaryfile).once
  end

  specify "should download a file correctly when the alternative, block syntax is used" do
    # prevent a real ftp session from being opened. If the lib attempts to open
    # a connection, just return a stubbed class
    ftp = Net::FTP.stub_instance(:login => true, :chdir => true, :nlst => ["1.ORD"], :getbinaryfile => true, :quit => true)
    Net::FTP.stub_method(:new => ftp, :open => ftp)
    File.stub_method(:read => "this is an order")

    RBook::Pacstream.open(@options) do |pac|
      pac.get(:orders) do |ord|
        ord.should eql("this is an order")
      end
    end

    Net::FTP.should have_received(:open).once.with(@options[:servername])
    ftp.should have_received(:login).once.with(@options[:username], @options[:password])
    ftp.should have_received(:chdir).twice
    ftp.should have_received(:nlst).once.without_args
    ftp.should have_received(:getbinaryfile).once
    ftp.should have_received(:quit).once.without_args
  end

  specify "should raise an exception if incorrect login details are provided" do
    # prevent a real ftp session from being opened. If the lib attempts to open
    # a connection, just return a stubbed class
    ftp = Net::FTP.stub_instance(:login => Net::FTPPermError.new("530 incorrect login. not logged in."))
    Net::FTP.stub_method(:new => ftp, :open => ftp)

    pac = RBook::Pacstream.new(@options)
    lambda { pac.login }.should raise_error(RBook::PacstreamAuthError)
  end

  specify "should raise an exception if an invalid server is provided" do
    # prevent a real ftp session from being opened. If the lib attempts to open
    # a connection, just return a stubbed class
    ftp = Net::FTP.stub_instance(:login => SocketError.new("getaddrinfo: Name or service not known"))
    Net::FTP.stub_method(:new => ftp, :open => ftp)

    pac = RBook::Pacstream.new(@options)
    lambda { pac.login }.should raise_error(RBook::PacstreamConnectionError)
  end

  specify "should save an order to the server" do
    # prevent a real ftp session from being opened. If the lib attempts to open
    # a connection, just return a stubbed class
    # this stub will allow the user to call chdir, and pretends that there is a single poa available
    # for download
    ftp = Net::FTP.stub_instance(:login => true, :chdir => true, :putbinaryfile => true, :quit => true)
    Net::FTP.stub_method(:new => ftp, :open => ftp)

    pac = RBook::Pacstream.new(@options)
    pac.login
    pac.put(:order, 1, "order content")
    pac.quit

    ftp.should have_received(:chdir).twice
    ftp.should have_received(:putbinaryfile).once
  end

  specify "should raise an exception if quit is called before login" do
    # prevent a real ftp session from being opened. If the lib attempts to open
    # a connection, just return a stubbed class
    ftp = Net::FTP.stub_instance(:login => true, :quit => true)
    Net::FTP.stub_method(:new => ftp, :open => ftp)

    pac = RBook::Pacstream.new(@options)
    lambda { pac.quit }.should raise_error(RBook::PacstreamCommandError)
  end
end
