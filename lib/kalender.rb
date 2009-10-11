require 'rubygems'
require 'sinatra'
require 'hpricot'
require 'open-uri'
require 'icalendar'
require 'date'
require 'kconv'

include Icalendar

get '/' do
  @studiengang = ["AR","AR3/VDPF","AR1/VHB","AR4/VIA","AR5/VPM","AR2/VSB","BI","BI5/BB","BI2/BS","BI4/GWV","BI3/HB","BI1/KI","BI/KI","BI/BB","EIT/AET","EIT/EET","EIT/MSR","EIT/NKT","EIT/PIL","EI","EI/AEE","EI/KTA","EI/MET","ET/AET","ET/AT","ET/NKT","EI/AET","EI/AT","EI/EET","EI/IAS","EI/KT","WET","IN/PI","IN/TI","IN","WM","WM/FVM","WM/OR","AM","MI","EG/EVT","EG/TGA","EG/UT","EU","MB/AMK","MB/MBI","MB/PT","MB","WME/EG","WME/MB","WME","WE","BK","BV","MU","DV/DT","DV/VT","MT","VH","SA","SW","WIB","BW","IM","F","FP","WT","GM","DT","VT","DV"]
  @p = params['post'].inspect

  params['post'] ||= {'jahrgang' => '', "studiengang" => "", "seminargruppe" => "", "abschluss" => ""}
  erb :index
end

get '/choose' do
  begin
    @link = "http://stundenplan.htwk-leipzig.de:8080/ws/Berichte/Text-Listen;Studenten-Sets;name;#{params['post']['jahrgang']}#{params['post']['studiengang']}#{params['post']['seminargruppe']}-#{params['post']['abschluss']}?template=UNEinzelGru&weeks=36-61&days=&periods=3-52&Width=0&Height=0"
    @doc = Hpricot(open(@link), :xhmtl_strict)
    @doc = (@doc/"table[@border='1']")
    @events = []

    @doc.each do |table|
      weekday = @doc.index(table)
      table = (table/"tr")#.to_a

      #delete every table header
      table.each_index do |n|
        table.slice!(n) if table[n].to_s.include? "Planungswochen"
      end

      table.each do |row|
        n = 0
        @event = Hash.new
        #add the weekday num before filling the hash with the other stuff
        @event.store(n,weekday)
        n += 1

        (row/"td").each do |col|
          @event.store(n,col.inner_html)
          n += 1
        end
        @events.push(@event)
      end
    end

    @events.each do |event|
      event[1] = splitweeks(event[1])
      event[2] = maketime(event[2])
      event[3] = maketime(event[3])
      #delete the last 2 columns "Bemerkungen" and "Gebucht am"
      event.delete(8)
      event.delete(9)
    end

    cal = Calendar.new

    @events.each do |event|
      event[1].each do |week|
        cal.event do
          #to calculate the Time with DateTime.commercial, we need the actual Year
          #the weeknums differ from the real calenderweeknums
          #we fix this with the getyear and getweek function
          dtstart     DateTime.commercial(getyear(week), getweek(week), event[0]+1, event[2][0].to_i, event[2][1].to_i, 0)
          dtend       DateTime.commercial(getyear(week), getweek(week), event[0]+1, event[3][0].to_i, event[3][1].to_i, 0)
          summary     event[5]
        end
      end
    end

    @cal_string = cal.to_ical.toutf8

  rescue OpenURI::HTTPError => e
    puts e
  end
end

def maketime(time)
  time.split(":")
end

def splitweeks(week)
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

def getyear(week)
  if week.to_i <= 53 then
    return 2009
  else
    return 2010
  end
end

def getweek(week)
  week = week.to_i
  if week > 53 then
    week -= 53
  end
  week
end