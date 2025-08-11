required_variables = []

# Only enforce master key in production
required_variables << 'RAILS_MASTER_KEY' if Rails.env.production?

missing_variables = required_variables.select { |var| ENV[var].nil? }

if missing_variables.any?
  raise "Missing required environment variables: #{missing_variables.join(', ')}"
end 