require 'rubygems'
require 'bundler'
Bundler.require(:default)

#ruby SB, no gem needed
require 'date'
require 'kconv'
require 'open-uri'
require 'net/http'
require 'rexml/document'
require "jcode"
require 'newrelic_rpm'
require 'digest/sha1'


#important for jlength
$KCODE = "UTF8"

include Icalendar

enable :sessions

configure :development do
  set :base_url, ''
end

#set base_url for heroku proxy
configure :production do
  set :base_url, 'kalender.nerdlabor.de'
end

# these helper methods are available in each erb view
helpers do

  # returns a string with encoded with html entities
  def html_special_char str
    if str.include? '&nbsp;'
      str.delete! '&nbsp;'
    else
      coder = HTMLEntities.new
      coder.encode(str)
    end
  end
end

get '/' do
  begin
    @htwk = get_study_data
    @@htwk = @htwk
    @e = throw_error(session['error'])
    erb :index
  rescue Exception => e
    @e = throw_error session['error'] = e.to_s + "<br />Der HTWK Server ist zur Zeit nicht erreichbar oder die Datenstruktur des Servers hat sich geändert. Sollte das Problem länger bestehen, schicke mir bitte eine Mail.<br /><br /> Mail an: ben [ätt] nerdlabor [punkt] de"
    erb :error
  end

end

get '/choose' do
  @e = throw_error(session['error'])
  @link = make_link(params['post']['jahrgang'],params['post']['studiengang'],params['post']['seminargruppe'],params['post']['abschluss'])
  @courses = get_courses(get_events(@link))
  session['backpath'] = request.fullpath #store this path for redirecting back to this, if there is an error on the next page
  erb :choose
end

get '/get/:link' do
  #this contruct is ugly, fix it!
  unless params['post'].nil?
    venue = params['post'].key?('venue') #get the venue key from the params hash
    params['post'].delete('venue') #delete the venue pair because we don't need it anymore
    params['post'].delete('')
    if params['post'].empty? #check if there any params
      session['error'] = "Bitte mindestens eine Veranstaltung auswählen!"
      redirect session['backpath']
    end
  else
    session['error'] = "Bitte mindestens eine Veranstaltung auswählen!"
    redirect session['backpath']
  end
  p = params['post'].keys
  p.map! do |n| #converts only the keys of the params hash to an array of integers
    n = n.to_i
  end
  wanted = []

  for i in 0..p.sort.last #converts an array of integers to an array of ones and zeros, example: [1,4,5] => [0,1,0,0,1,1]
    if p.include?(i) then
      wanted.push(1)
    else
      wanted.push(0)
    end
  end
  @permalink = make_permalink(wanted,venue)
  @downloadlink = make_downloadlink(params[:link],wanted,venue)
  erb :get
end

get '/get/:link/:venue/*' do
  content_type 'text/html', :charset => 'utf-8'
  make_cal(only_use_wanted_events(get_events(params[:link]),splat_to_array(params[:splat])),params[:link],params[:venue])
end

get '/file/:link/:venue/*.ics' do
  content_type 'application/octet-stream', :charset => 'utf-8'
  make_cal(only_use_wanted_events(get_events(params[:link]),splat_to_array(params[:splat])),params[:link],params[:venue])
end

#makes false => "0" and true => "1"
def bool_to_str(bool)
  if bool == true then
    "1"
  else
    "0"
  end
end

#returns a errormessage as string
def throw_error(message)
  session.delete('error')
  "<p class=\"error\">" + message + "</p>" unless message.nil?
end

#returns an array of ones and zeros
def splat_to_array(splat)
  wanted = splat[0].split("/")
  wanted.map! do |n|
    n = n.to_i
  end
  wanted
end

#returns a String which is the downloadlink
def make_downloadlink(link,wanted,venue)
  begin
    #FIXME get_port doesnt work
    #old: "http://" + request.host + get_port + "/file/" + link + "/" + bool_to_str(venue) + "/" + wanted.join("/") + "/" +@@link.sub("/","_") +".ics"
		options.base_url = request.host if options.base_url == ''
    "http://" + options.base_url + "/file/" + link + "/" + bool_to_str(venue) + "/" + wanted.join("/") + "/" + link.sub("/","_") +".ics"
  rescue Exception => e
    @e = throw_error session['error'] = e.to_s + "<br />(Es ist ein Fehler aufgetreten. Bitte sende mir die Fehlermeldung per Mail.)"
    erb :error
  end
end

#returns a String which is the permalink
def make_permalink(wanted,venue)
  #FIXME get_port doesnt work
  #old: "http://" + request.host + get_port + request.path_info + "/" + bool_to_str(venue) + "/" + wanted.join("/")
	options.base_url = request.host if options.base_url == ''
  "http://" + options.base_url + request.path_info + "/" + bool_to_str(venue) + "/" + wanted.join("/")
end

#deletes all unwanted events and returns an Array
#wanted must be an Array of ones and zeros
def only_use_wanted_events(events,wanted)
  wanted_courses = []
  new_events = []
  courses = get_courses(events) #get all courses from the events array

  courses.each_index do |w| #only push wanted courses to the wanted_courses array
    wanted_courses.push(courses[w]) if wanted[w] == 1
  end

  wanted_courses.each do |wanted_event|
    events.each_index do |event_index|
      new_events.push(events[event_index]) if events[event_index][5] == wanted_event
    end
  end
  new_events
end

#returns a String for the URL
def make_link(year,study,group,degree)
  #correct integration of semgrp number in string
  if study.include? "/"
    study.insert(study.index("/"), group)
    link = year+study+"-"+degree
  else
    link = year+study+group+"-"+degree
  end
  @@link = link
  link
end

#returns an Array with all Courses
def get_courses(events)
  courses = []
  events.each do |event|
    courses.push(event[5])
  end
  courses = courses.uniq.sort
end

#returns a String in iCal Format
def make_cal(events,link,venue)
  cal = Calendar.new

  cal.product_id = "-//kalender.nerdlabor.org//NERDCAL 2.0//DE"
  cal.custom_property("X-WR-CALNAME", "#{link.sub("-","")}")
  cal.custom_property("X-WR-CALDESC", "#{link.sub("-","")}")
  cal.custom_property("X-WR-TIMEZONE", "Europe/Berlin")

  cal.timezone do
    timezone_id             "Europe/Berlin"

    daylight do
      timezone_offset_from  "+0100"
      timezone_offset_to    "+0200"
      timezone_name         "CEST"
      dtstart               "19700329T020000"
      add_recurrence_rule   "FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU"
    end

    standard do
      timezone_offset_from  "+0200"
      timezone_offset_to    "+0100"
      timezone_name         "CET"
      dtstart               "19701025T030000"
      add_recurrence_rule   "FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU"
    end
  end


  events.each do |event|
    event[1].each do |week|
      cal.event do
        uid         "#{Digest::SHA1.hexdigest event.to_s}@kalender.nerdlabor.de"
        dtstart     DateTime.commercial(get_year(week), get_week(week), event[0]+1, event[2][0], event[2][1], 0) #to calculate the Time with DateTime.commercial, we need the actual Year
        dtend       DateTime.commercial(get_year(week), get_week(week), event[0]+1, event[3][0], event[3][1], 0) #the weeknums differ from the real calenderweeknums, we fix this with the get_year and get_week function
        location    event[4]
        summary     event[5] + " " + event[6] + " " + print_info(event[7]) + print_info(event[4]) if venue == "1"
        summary     event[5] + " " + event[6] + " " + print_info(event[7]) if venue == "0"
      end
    end
  end
  cal.to_ical #generate ical text
end

#returns a string with braces or an empty string
def print_info(info)
  info = "" if info == "&nbsp\;"
  unless info.empty?
    "(" + info + ")"
  else
    ""
  end
end

#returns a hash with data for year, course, group and degree
def get_study_data
  begin
    url = "http://stundenplan.htwk-leipzig.de:8080/stundenplan/studienjahr.xml"

    #get semester, semester id, time
    xml_data = Net::HTTP.get_response(URI.parse(url)).body
    doc = REXML::Document.new(xml_data)
    semester = doc.root.elements["semester"].attributes["name"]
    zeitraum = doc.root.elements["semester/period"].attributes["name"]
    sid = doc.root.elements["semester"].attributes["id"]

    #choose right semester (season)
    if sid == "ss"
      url = 'http://stundenplan.htwk-leipzig.de:8080/stundenplan/semgrp/semgrp_ss.xml'
    else
      url = 'http://stundenplan.htwk-leipzig.de:8080/stundenplan/semgrp/semgrp_ws.xml'
    end



    # get the XML data as a string
    xml_data = Net::HTTP.get_response(URI.parse(url)).body

    # Array with parsed strings from xml file
    htwk_strings = []

    # extract study_path information
    doc = REXML::Document.new(xml_data)
    doc.elements.each("studium/fakultaet/studiengang/semgrp") do |element|
      htwk_strings.push(element.attributes["id"])
    end



    jahrgang = []
    studiengang = []
    # if no smgrp exists, default
    seminargruppe = [""]
    abschluss = []

    htwk_strings.collect do |str|
      jahrgang << str.match(/^\d{2}/)[0]
      studiengang << str.match(/^\d{2}(.+)\-/)[1]
      abschluss << str.match(/\-(.+)$/)[1]
    end

    # get list of seminargroups from string part "studiengang"
    studiengang.collect! do |str|
      # it´s a number?
      if /\d+$/.match(str)
        #fill the array and remove the number from string
        seminargruppe << $&
        str.slice! $&
        str
      end
      str
    end

    jahrgang.uniq!.sort!
    studiengang.uniq!.sort!
    seminargruppe.uniq!.sort!
    abschluss.uniq!.sort!

    #returns hash with all data
    {"sid" => sid, "semester" => semester, "zeitraum" => zeitraum, "jahrgang" => jahrgang, "studiengang" => studiengang, "seminargruppe" => seminargruppe, "abschluss" => abschluss}

  #FIXME this exceptions will never be thrown because this function is in an rescue block! see get '/' do
  rescue NoMethodError => e
    @e = throw_error session['error'] = e.to_s + "<br />(Scheinbar ist der HTWK Kalender Server nicht erreichbar.)"
    erb :error
  rescue Errno::EHOSTUNREACH => e
    @e = throw_error session['error'] = e.to_s + "<br />(Scheinbar ist der HTWK Kalender Server nicht erreichbar.)"
    erb :error
  rescue Exception => e
    @e = throw_error session['error'] = e.to_s + "<br />(Es ist ein Fehler aufgetreten. Bitte sende mir die Fehlermeldung per Mail.)"
    erb :error
  end
end

#returns an array with all calendar data
def get_events(link)
  #HTWK url needs "/"
  link = link.sub("_","/").sub(" ", "%20")

  begin
    if @@htwk['sid'] == 'ss'
      link = "http://stundenplan.htwk-leipzig.de:8080/ss/Berichte/Text-Listen;Studenten-Sets;name;#{link}?template=UNEinzelGru&weeks=0-53"
    else
      link = "http://stundenplan.htwk-leipzig.de:8080/ws/Berichte/Text-Listen;Studenten-Sets;name;#{link}?template=UNEinzelGru&weeks=0-53"
    end

    doc = Hpricot(open(link), :xhmtl_strict)
    doc = (doc/"table[@border='1']")
    events = []

    doc.each do |table|
      weekday = doc.index(table)
      table = (table/"tr")

      table.each_index do |n|
        table.slice!(n) if table[n].to_s.include? "Planungswochen" #delete every table header
      end

      table.each do |row|
        n = 0
        event = Hash.new
        event.store(n,weekday)#add the weekday num before filling the hash with the other stuff
        n += 1
        (row/"td").each do |col|
          event.store(n,col.inner_html)
          n += 1
        end
        events.push(event)
      end
    end

    events.each do |event|
      event[1] = split_weeks(event[1])
      event[2] = make_time(event[2])
      event[3] = make_time(event[3])
      event[4] = "" if event[4] == "&nbsp\;" #empty the string if its just a html whitespace
      event[5] = event[5].unpack('C*').pack('U*') #unpack and pack convert the iso-8859-1 to utf-8
      event[7] = event[7].unpack('C*').pack('U*')
      event.delete(8) #delete the last 2 columns "Bemerkungen" and "Gebucht am"
      event.delete(9)
    end

  rescue OpenURI::HTTPError => e
    session['error'] = e.to_s + "<br />(Scheinbar hast du eine Kombination gewählt, die es nicht gibt)"
    redirect '/'
  rescue Errno::EHOSTUNREACH => e
    session['error'] = e.to_s + "<br />(Scheinbar ist der HTWK Kalender Server nicht erreichbar.)"
    redirect '/'
  rescue Exception => e
    session['error'] = e.to_s + "<br />(Es ist ein Fehler aufgetreten. Bitte sende mir die Fehlermeldung per Mail.)"
    redirect '/'
  end
end

#retuns an Array with Hour and Minute
def make_time(time)
  time = time.split(":")
  time[0] = time[0].to_i
  time[1] = time[1].to_i
  time
end

#returns an Array with all CWeeks
def split_weeks(week)
  a = []
  split = week.split(", ")
  split.each do |n|
    if n.include?("-") then
      interval = n.split("-")
      for i in interval[0]..interval[1]
        a.push(i)
      end
    else
      a.push(n)
    end
  end
  a
end

# returns the right year
def get_year(week)
  begin
    year = @@htwk["semester"].scan /\d+/
    cweek_count = Date.civil(year[0].to_i,12,31).cweek
    if week.to_i <= cweek_count or cweek_count == 1 then
      year[0].to_i
    else
      year[0].to_i+1
    end

  rescue Exception => e
    @e = throw_error session['error'] = e.to_s + "<br />Bitte starten deine Kalenderanfrage erneut. Sollte das Problem länger bestehen, schicke mir bitte eine Mail an:</br> ben [ätt] nerdlabor [punkt] de"
    redirect '/'
  end

end

#just a Hack, change Planweeks to real CWeeks, example: 57 => 4
def get_week(week)
  #check how much cweeks the current year has
  year = @@htwk["semester"].scan /\d+/
  cweek_count = Date.civil(year[0].to_i,12,31).cweek

  week = week.to_i

  if week > cweek_count and cweek_count != 1 then
    week -= cweek_count
  end
  week
end

# returns port of sinatra application
def get_port
  current_port = Sinatra::Application.port.to_s
  if current_port != "80"
    ":"+ current_port
  else
    ""
  end
end
