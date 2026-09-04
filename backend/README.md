# Steptrack Backend API - Spring Boot + PostgreSQL

## Overview
RESTful API for the Steptrack Flutter app, built with Spring Boot 3.3.0 and PostgreSQL. Handles user authentication (JWT), Google OAuth, and user profile management.

## Prerequisites
- **Java 21+**
- **Maven 3.9+**
- **PostgreSQL 14+**
- **Git**

## Database Setup

### 1. Create Database
```bash
psql -U postgres
CREATE DATABASE steptrack;
```

### 2. Create Tables
Connect to the `steptrack` database and run:
```sql
-- Users (authentication)
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User Profiles
CREATE TABLE user_profiles (
  id UUID PRIMARY KEY REFERENCES users(id),
  full_name VARCHAR(255),
  age INTEGER,
  weight_kg DECIMAL(5,2),
  height_cm DECIMAL(5,2),
  gender VARCHAR(20),
  profile_completed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for better performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_user_profiles_profile_completed ON user_profiles(profile_completed);
```

## Configuration

### 1. Update Database Credentials
Edit `src/main/resources/application.properties`:
```properties
spring.datasource.username=postgres
spring.datasource.password=your_actual_password
```

### 2. Set Up JWT Secret
In `application.properties`, update the JWT secret (minimum 256 bits):
```properties
jwt.secret=your-very-long-secret-key-minimum-256-bits-long-for-production-security
```

### 3. Google OAuth Configuration (Optional)
For Google OAuth support, set environment variables:
```bash
export GOOGLE_CLIENT_ID=your_google_client_id
export GOOGLE_CLIENT_SECRET=your_google_client_secret
```

Or add to `application.properties`:
```properties
spring.security.oauth2.client.registration.google.client-id=your_client_id
spring.security.oauth2.client.registration.google.client-secret=your_secret
```

## Build & Run

### Build
```bash
mvn clean package
```

### Run
```bash
mvn spring-boot:run
```

The API will start on `http://localhost:8080/api`

## API Endpoints

### Authentication
- **POST** `/api/auth/register` - Register new user
- **POST** `/api/auth/login` - Login with email/password
- **POST** `/api/auth/google` - Login with Google ID token
- **POST** `/api/auth/logout` - Logout (client-side handled)

### Profile
- **GET** `/api/profile` - Get current user's profile (requires auth)
- **PUT** `/api/profile` - Update user's profile (requires auth)

### Health
- **GET** `/api/health` - Health check

## Testing with cURL

### Health Check
```bash
curl http://localhost:8080/api/health
```

### Register User
```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123",
    "passwordConfirm": "password123"
  }'
```

### Login
```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123"
  }'
```

### Get Profile (requires token)
```bash
curl -X GET http://localhost:8080/api/profile \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### Update Profile (requires token)
```bash
curl -X PUT http://localhost:8080/api/profile \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "fullName": "John Doe",
    "age": 30,
    "weightKg": 75.50,
    "heightCm": 180,
    "gender": "M",
    "profileCompleted": true
  }'
```

## Project Structure
```
src/main/java/com/steptrack/
├── controller/          # REST endpoints
├── service/             # Business logic
├── model/               # JPA entities
├── repository/          # Data access layer
├── dto/                 # Data transfer objects
├── security/            # JWT & authentication
└── SteptrackApiApplication.java  # Main application
```

## Error Handling
- **400 Bad Request** - Invalid input or validation failure
- **401 Unauthorized** - Invalid credentials or missing token
- **404 Not Found** - Resource not found
- **500 Internal Server Error** - Server error

## CORS Configuration
Allowed origins (configured in `SecurityConfig`):
- `http://localhost:3000`
- `http://localhost:8081`
- `http://localhost:8080`

Modify `SecurityConfig.java` to add/change allowed origins.

## Logging
Logs are configured in `application.properties`:
- **Root Level**: INFO
- **Steptrack Package**: DEBUG
- **Spring Security**: DEBUG

Enable request/response logging by setting:
```properties
logging.level.org.springframework.web=DEBUG
```

## Security Notes
- Passwords are hashed using BCrypt
- JWT tokens expire after 24 hours (configurable via `jwt.expiration`)
- All authenticated endpoints require valid Bearer token
- Google OAuth tokens are verified before user creation
- CORS is configured for specified origins only

## Common Issues

### Database Connection Failed
- Check PostgreSQL is running
- Verify credentials in `application.properties`
- Ensure database `steptrack` exists

### JWT Token Errors
- Token may have expired (default 24 hours)
- Check Bearer token format: `Authorization: Bearer <token>`
- Verify JWT secret matches in both generation and validation

### Google OAuth Issues
- Ensure Google client credentials are set
- Token must include email scope
- Token must not be expired

## Next Steps
After backend setup, proceed to Phase 3: Update Flutter frontend to use this API instead of Supabase.

## License
Proprietary - Steptrack

### 3. Google OAuth Configuration (Optional)

To enable Google login, set environment variables:

```bash
export GOOGLE_CLIENT_ID=your-client-id
export GOOGLE_CLIENT_SECRET=your-client-secret
```

Or add to `application.properties`.

## Building

```bash
mvn clean package
```

## Running

```bash
mvn spring-boot:run
```

The API will be available at: `http://localhost:8080/api`

## API Endpoints

### Authentication

- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login with email/password
- `POST /api/auth/google` - Login with Google
- `POST /api/auth/logout` - Logout

### Profile

- `GET /api/profile` - Get current user's profile (requires JWT token)
- `PUT /api/profile` - Update current user's profile (requires JWT token)

## Project Structure

```
src/main/java/com/steptrack/
├── controller/        # REST controllers
├── service/          # Business logic services
├── model/            # JPA entities
├── repository/       # Spring Data repositories
├── security/         # Security configuration & JWT
└── dto/              # Data Transfer Objects
```

## Testing

```bash
mvn test
```

## Next Steps

After backend implementation:
1. Update Flutter app to use this API instead of Supabase
2. Configure CORS properly for your deployment environment
3. Implement data migration from Supabase to PostgreSQL
4. Add additional features (step tracking, analytics, etc.)
