# Uniladder

A modern web application built with Rails 8.0.1.

## Installation

1. Clone the repository
2. Install dependencies: 
```bash
bundle install
```
3. Set up environment variables: 
```bash
cp .env.template .env
# Edit .env with your values
```

## Environment Variables

The following environment variables are required:

- `DATABASE_URL`: PostgreSQL connection URL
- `RAILS_MASTER_KEY`: Rails master key for credentials
- `APP_HOST`: Application host (e.g., localhost:3000)
- `KAMAL_REGISTRY_PASSWORD`: Docker registry password (for deployment)

## Development

1. Set up your environment variables
2. Start the server: 
```bash
bin/dev
```

## Deployment

Deployment is handled by Kamal 2. Make sure all environment variables are properly set in your deployment environment. 