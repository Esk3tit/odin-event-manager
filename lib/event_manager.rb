require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(number)
  # Convert to string in case of nil, then clean all characters except digits
  # pad with 0s until valid length for bad numbers, then check prefix and length
  # if 1
  standard_phone_num = number.to_s.gsub(/[^0-9]/, '').rjust(10, '0')
  if standard_phone_num.length == 11 && standard_phone_num[0] == '1'
    standard_phone_num[1..10]
  else
    standard_phone_num[0..9]
  end
end

def find_peak_registration_hours(registration_date_list)
  # Get the hour from the regdate column. We don't care about the actual date
  # count each hour and then list out in sorted desc order for most common hours of reg
  # use 24 hour format since we want to differentiate between AM/PM but print in 12 hr
  # format for intuitive reading
  hours_list = registration_date_list.map { |regdate| Time.strptime(regdate, "%m/%d/%y %k:%M").hour }
  hour_count = hours_list.each_with_object(Hash.new(0)) { |hour,counter| counter[hour] += 1 }
  hour_count.sort_by(&:last).reverse
end

def print_peak_registration_hours(sorted_hours_freq_list)
  puts "Here are the most frequent registration hours and their counts:"
  sorted_hours_freq_list.each { |hour_freq| puts "Hour: #{Time.strptime(hour_freq[0].to_s, "%k").strftime("%I %p")} | Frequency: #{hour_freq[1]}" }
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read('secret.key').strip

  begin
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue 
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'Event Manager Initialized!'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

regdate_list = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  phone_num = clean_phone_number(row[:homephone])
  regdate_list << row[:regdate]
  puts "#{phone_num}"

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

# Format function for time here
print_peak_registration_hours(find_peak_registration_hours(regdate_list))