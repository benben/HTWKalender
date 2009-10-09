require 'sinatra'

#Sinatra::Application.default_options.merge!(
#  :run => false,
#  :environment => :production
#)

log = File.open("kalender.log", "a+")
STDERR.reopen log
STDOUT.reopen log
log << "----- SERVER STARTING -----"

require 'kalender'
run Sinatra::Application