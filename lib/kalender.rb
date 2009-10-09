require 'rubygems'
require 'sinatra'

get '/' do
  @studiengang = ["AR","AR3/VDPF","AR1/VHB","AR4/VIA","AR5/VPM","AR2/VSB","BI","BI5/BB","BI2/BS","BI4/GWV","BI3/HB","BI1/KI","BI/KI","BI/BB","EIT/AET","EIT/EET","EIT/MSR","EIT/NKT","EIT/PIL","EI","EI/AEE","EI/KTA","EI/MET","ET/AET","ET/AT","ET/NKT","EI/AET","EI/AT","EI/EET","EI/IAS","EI/KT","WET","IN/PI","IN/TI","IN","WM","WM/FVM","WM/OR","AM","MI","EG/EVT","EG/TGA","EG/UT","EU","MB/AMK","MB/MBI","MB/PT","MB","WME/EG","WME/MB","WME","WE","BK","BV","MU","DV/DT","DV/VT","MT","VH","SA","SW","WIB","BW","IM","F","FP","WT","GM","DT","VT","DV"]
  @p = params['post'].inspect
  erb :index
end