json.extract!(register, :acc_url, :title, :priority_date)
json.url register_url(register, format: :json)
