# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def sparkline(array_of_values)
    if array_of_values.size > 50
      array_of_values = array_of_values.in_groups_of(array_of_values.size / 50).collect{|group|group.compact.sum}
    end
    image_tag "http://chart.apis.google.com/chart?chxl=0:||1:|&chxs=0,000000,10,0,_|1,000000,10,0,_&cht=lc&chxt=x,y&chs=100x50&chco=0077CC&chm=B,E6F2FA,0,0,0&chd=e:#{extended_encode(array_of_values, array_of_values.max)}", :alt => "sparklines", :title => "sparklines"
  end
  
  def extended_encode(data_arr, max_value)
    # Douglas F Shearer 2007
    # http://douglasfshearer.com/blog/ruby-google-charts-api-data-encoding
    characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-.'.split(//)
    data = ''
    data_arr.each do |value|
      if value.is_a?(Integer) && value >= 0
        new_value = (max_value == 0 ? 0 : (4095 * value.to_f / max_value.to_f)).to_i
        sixtyfours = new_value/64
        units = new_value%64
        p '64:' + sixtyfours.to_s
        p 'units: ' + units.to_s
        data << characters[sixtyfours] + characters[units]
      else
        data << '__'
      end
    end
    data
  end

end
