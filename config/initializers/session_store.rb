# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_collaborytics_session',
  :secret      => '00c1b1a6c56416fc45bb7960fe30da04bc70744a3365a1ff6cd8bcd33bb3396208ecab63b0efbfa5b44870d90cdf8066ab4e483a03ce24866cdbb421311032df'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
