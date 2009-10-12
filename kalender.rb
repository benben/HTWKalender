require 'rubygems'
require 'sinatra'
require 'hpricot'
require 'open-uri'
require 'icalendar'
require 'date'
require 'kconv'

include Icalendar

enable :sessions

get '/' do
  @studiengang = ["AR","AR3/VDPF","AR1/VHB","AR4/VIA","AR5/VPM","AR2/VSB","BI","BI5/BB","BI2/BS","BI4/GWV","BI3/HB","BI1/KI","BI/KI","BI/BB","EIT/AET","EIT/EET","EIT/MSR","EIT/NKT","EIT/PIL","EI","EI/AEE","EI/KTA","EI/MET","ET/AET","ET/AT","ET/NKT","EI/AET","EI/AT","EI/EET","EI/IAS","EI/KT","WET","IN/PI","IN/TI","IN","WM","WM/FVM","WM/OR","AM","MI","EG/EVT","EG/TGA","EG/UT","EU","MB/AMK","MB/MBI","MB/PT","MB","WME/EG","WME/MB","WME","WE","BK","BV","MU","DV/DT","DV/VT","MT","VH","SA","SW","WIB","BW","IM","F","FP","WT","GM","DT","VT","DV"]
  @e = throw_error(session['error'])
  erb :index
end

get '/choose' do
  @e = throw_error(session['error'])
  @link = make_link(params['post']['jahrgang'],params['post']['studiengang'],params['post']['seminargruppe'],params['post']['abschluss'])
  @courses = get_courses(get_events(@link))
  session['backpath'] = request.fullpath #store this path for redirecting back to this, if there is an error on the next page
  erb :choose
end

get '/get/:link' do
  if params['post'].nil? then #check if there any params
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
  @permalink = make_permalink(wanted)
  @downloadlink = make_downloadlink(params[:link],wanted)
  erb :get
end

get '/get/:link/*' do
  make_cal(only_use_wanted_events(get_events(params[:link]),splat_to_array(params[:splat])))
end

get '/file/:link/*.ics' do
  content_type 'application/octet-stream', :charset => 'utf-8'
  make_cal(only_use_wanted_events(get_events(params[:link]),splat_to_array(params[:splat])))
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
def make_downloadlink(link,wanted)
  "http://" + request.host + "/file/" + link + "/" + wanted.join("/") + ".ics"
end

#returns a String which is the permalink
def make_permalink(wanted)
  "http://" + request.host + request.path_info + "/" + wanted.join("/")
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
  year+study+group+"-"+degree
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
def make_cal(events)
  cal = Calendar.new

  events.each do |event|
    event[1].each do |week|
      cal.event do
        dtstart     DateTime.commercial(get_year(week), get_week(week), event[0]+1, event[2][0].to_i, event[2][1].to_i, 0) #to calculate the Time with DateTime.commercial, we need the actual Year
        dtend       DateTime.commercial(get_year(week), get_week(week), event[0]+1, event[3][0].to_i, event[3][1].to_i, 0) #the weeknums differ from the real calenderweeknums, we fix this with the get_year and get_week function
        summary     event[5]
      end
    end
  end
  cal.to_ical #generate ical text
end

#returns an array with all calendar data
def get_events(link)
  begin
    link = "http://stundenplan.htwk-leipzig.de:8080/ws/Berichte/Text-Listen;Studenten-Sets;name;#{link}?template=UNEinzelGru&weeks=36-61&days=&periods=3-52&Width=0&Height=0"
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
      event[5] = event[5].unpack('C*').pack('U*') #unpack and pack convert the iso-8859-1 to utf-8
      event[7] = event[7].unpack('C*').pack('U*')
      event.delete(8) #delete the last 2 columns "Bemerkungen" and "Gebucht am"
      event.delete(9)
    end

    events

  rescue OpenURI::HTTPError => e
    session['error'] = e.to_s + "<br />(Scheinbar hast du eine Kombination gewählt, die es nicht gibt)"
    redirect '/'
  end
end

#retuns an Array with Hour and Minute
def make_time(time)
  time.split(":")
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

#just a Hack, returns 2010 if week is > 53
def get_year(week)
  if week.to_i <= 53 then
    return 2009
  else
    return 2010
  end
end

#just a Hack, change Planweeks to real CWeeks, example: 57 => 4
def get_week(week)
  week = week.to_i
  if week > 53 then
    week -= 53
  end
  week
end