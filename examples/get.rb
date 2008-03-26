# assuming you have rbook installed via rubygems,
# in a regular script you should replace the following require
# line with these 2 lines:
#   require 'rubygems'
#   require 'rbook/pacstream'
require File.dirname(__FILE__) + '/../lib/rbook/pacstream'

counter = 0

RBook::Pacstream.open(:username => "myusername", :password => "mypass") do |pac|
  pac.get(:orders) do |order|
    File.open("#{counter.to_s}.ord", "w") { |f| f.puts order }
    counter += 1
  end
end
