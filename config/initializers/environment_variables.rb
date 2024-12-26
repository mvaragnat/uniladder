required_variables = %w[
  DATABASE_URL
  RAILS_MASTER_KEY
  APP_HOST
]

missing_variables = required_variables.select { |var| ENV[var].nil? }

if missing_variables.any?
  raise "Missing required environment variables: #{missing_variables.join(', ')}"
end 