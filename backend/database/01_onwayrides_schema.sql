-- OnWay Rides initial MySQL schema
-- Import this file first in phpMyAdmin.
-- Target: MySQL 8.x / MariaDB with InnoDB and utf8mb4 support.

SET NAMES utf8mb4;
SET time_zone = '+00:00';
SET foreign_key_checks = 0;

CREATE DATABASE IF NOT EXISTS `onwayrides_onwayrides`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE `onwayrides_onwayrides`;

CREATE TABLE IF NOT EXISTS system_settings (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `group` VARCHAR(100) NOT NULL DEFAULT 'general',
  `key` VARCHAR(150) NOT NULL,
  value_text TEXT NULL,
  value_json JSON NULL,
  is_public TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_system_settings_key (`group`, `key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS cities (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(120) NOT NULL,
  slug VARCHAR(120) NOT NULL,
  province VARCHAR(120) NULL,
  country_code CHAR(2) NOT NULL DEFAULT 'PK',
  latitude DECIMAL(10,7) NULL,
  longitude DECIMAL(10,7) NULL,
  is_enabled TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_cities_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS zones (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  city_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(150) NOT NULL,
  slug VARCHAR(150) NOT NULL,
  zone_type ENUM('urban', 'airport', 'intercity', 'school', 'delivery', 'custom') NOT NULL DEFAULT 'urban',
  center_latitude DECIMAL(10,7) NULL,
  center_longitude DECIMAL(10,7) NULL,
  radius_km DECIMAL(8,2) NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_zones_city_slug (city_id, slug),
  CONSTRAINT fk_zones_city FOREIGN KEY (city_id) REFERENCES cities(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS service_types (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(120) NOT NULL,
  slug VARCHAR(120) NOT NULL,
  category ENUM('ride', 'delivery', 'rental', 'food', 'school', 'airport', 'prebooking') NOT NULL,
  description TEXT NULL,
  supports_negotiation TINYINT(1) NOT NULL DEFAULT 0,
  supports_scheduling TINYINT(1) NOT NULL DEFAULT 1,
  supports_driver_mode TINYINT(1) NOT NULL DEFAULT 1,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_service_types_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS city_service_settings (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  city_id BIGINT UNSIGNED NOT NULL,
  service_type_id BIGINT UNSIGNED NOT NULL,
  is_enabled TINYINT(1) NOT NULL DEFAULT 1,
  supports_negotiation TINYINT(1) NOT NULL DEFAULT 0,
  supports_scheduling TINYINT(1) NOT NULL DEFAULT 1,
  base_eta_minutes INT NULL,
  min_distance_km DECIMAL(8,2) NULL,
  max_distance_km DECIMAL(8,2) NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_city_service (city_id, service_type_id),
  CONSTRAINT fk_city_service_city FOREIGN KEY (city_id) REFERENCES cities(id),
  CONSTRAINT fk_city_service_type FOREIGN KEY (service_type_id) REFERENCES service_types(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS subscription_plans (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code VARCHAR(80) NOT NULL,
  name VARCHAR(150) NOT NULL,
  audience ENUM('driver', 'fleet_owner') NOT NULL,
  billing_cycle ENUM('weekly', 'monthly', 'quarterly', 'yearly') NOT NULL,
  amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  currency CHAR(3) NOT NULL DEFAULT 'PKR',
  lower_commission_percent DECIMAL(5,2) NULL,
  max_active_vehicles INT NULL,
  max_active_drivers INT NULL,
  benefits_json JSON NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_subscription_plans_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS vehicle_categories (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(100) NOT NULL,
  slug VARCHAR(100) NOT NULL,
  icon_name VARCHAR(100) NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_vehicle_categories_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS vehicle_types (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  vehicle_category_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(120) NOT NULL,
  slug VARCHAR(120) NOT NULL,
  seats INT NULL,
  luggage_capacity INT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_vehicle_types_slug (slug),
  CONSTRAINT fk_vehicle_types_category FOREIGN KEY (vehicle_category_id) REFERENCES vehicle_categories(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS vehicle_makes (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(120) NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_vehicle_makes_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS vehicle_models (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  vehicle_make_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(120) NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_vehicle_models_make_name (vehicle_make_id, name),
  CONSTRAINT fk_vehicle_models_make FOREIGN KEY (vehicle_make_id) REFERENCES vehicle_makes(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  firebase_uid VARCHAR(191) NULL,
  full_name VARCHAR(191) NOT NULL,
  first_name VARCHAR(100) NULL,
  last_name VARCHAR(100) NULL,
  email VARCHAR(191) NULL,
  phone VARCHAR(30) NULL,
  country_code VARCHAR(8) NOT NULL DEFAULT '+92',
  password_hash VARCHAR(255) NULL,
  role ENUM('admin', 'rider', 'driver', 'fleet_owner', 'merchant', 'support') NOT NULL DEFAULT 'rider',
  status ENUM('pending', 'active', 'suspended', 'blocked', 'deleted') NOT NULL DEFAULT 'pending',
  avatar_url VARCHAR(255) NULL,
  national_id_number VARCHAR(50) NULL,
  referral_code VARCHAR(50) NULL,
  referred_by_user_id BIGINT UNSIGNED NULL,
  email_verified_at TIMESTAMP NULL DEFAULT NULL,
  phone_verified_at TIMESTAMP NULL DEFAULT NULL,
  last_login_at TIMESTAMP NULL DEFAULT NULL,
  metadata JSON NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_users_firebase_uid (firebase_uid),
  UNIQUE KEY uk_users_email (email),
  UNIQUE KEY uk_users_phone (phone),
  UNIQUE KEY uk_users_referral_code (referral_code),
  KEY idx_users_role_status (role, status),
  CONSTRAINT fk_users_referred_by FOREIGN KEY (referred_by_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS rider_profiles (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  preferred_language VARCHAR(20) NOT NULL DEFAULT 'en',
  default_payment_method ENUM('cash', 'wallet', 'card') NOT NULL DEFAULT 'cash',
  home_address VARCHAR(255) NULL,
  work_address VARCHAR(255) NULL,
  emergency_contact_name VARCHAR(150) NULL,
  emergency_contact_phone VARCHAR(30) NULL,
  average_rating DECIMAL(3,2) NOT NULL DEFAULT 5.00,
  total_trips INT NOT NULL DEFAULT 0,
  notes TEXT NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_rider_profiles_user (user_id),
  CONSTRAINT fk_rider_profiles_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS fleet_owners (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  city_id BIGINT UNSIGNED NULL,
  fleet_code VARCHAR(30) NOT NULL,
  company_name VARCHAR(191) NOT NULL,
  business_model ENUM('commission', 'subscription', 'hybrid') NOT NULL DEFAULT 'hybrid',
  status ENUM('pending', 'active', 'suspended', 'blocked') NOT NULL DEFAULT 'pending',
  payout_schedule ENUM('daily', 'weekly', 'monthly') NOT NULL DEFAULT 'weekly',
  support_email VARCHAR(191) NULL,
  support_phone VARCHAR(30) NULL,
  office_address VARCHAR(255) NULL,
  commission_percent_override DECIMAL(5,2) NULL,
  notes TEXT NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_fleet_owners_user (user_id),
  UNIQUE KEY uk_fleet_owners_code (fleet_code),
  CONSTRAINT fk_fleet_owners_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_fleet_owners_city FOREIGN KEY (city_id) REFERENCES cities(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS driver_profiles (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  fleet_owner_id BIGINT UNSIGNED NULL,
  city_id BIGINT UNSIGNED NULL,
  driver_code VARCHAR(40) NULL,
  license_number VARCHAR(100) NULL,
  business_model ENUM('commission', 'subscription', 'hybrid') NOT NULL DEFAULT 'commission',
  status ENUM('pending', 'active', 'suspended', 'blocked', 'rejected') NOT NULL DEFAULT 'pending',
  onboarding_status ENUM('draft', 'documents_pending', 'review', 'approved', 'rejected') NOT NULL DEFAULT 'draft',
  is_online TINYINT(1) NOT NULL DEFAULT 0,
  is_busy TINYINT(1) NOT NULL DEFAULT 0,
  accepts_cash TINYINT(1) NOT NULL DEFAULT 1,
  accepts_wallet TINYINT(1) NOT NULL DEFAULT 0,
  accepts_card TINYINT(1) NOT NULL DEFAULT 0,
  rating_average DECIMAL(3,2) NOT NULL DEFAULT 5.00,
  rating_count INT NOT NULL DEFAULT 0,
  trips_completed INT NOT NULL DEFAULT 0,
  wallet_hold_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  last_latitude DECIMAL(10,7) NULL,
  last_longitude DECIMAL(10,7) NULL,
  last_location_at DATETIME NULL,
  notes TEXT NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_driver_profiles_user (user_id),
  UNIQUE KEY uk_driver_profiles_code (driver_code),
  KEY idx_driver_profiles_fleet_status (fleet_owner_id, status),
  KEY idx_driver_profiles_online_busy (is_online, is_busy),
  CONSTRAINT fk_driver_profiles_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_driver_profiles_fleet FOREIGN KEY (fleet_owner_id) REFERENCES fleet_owners(id),
  CONSTRAINT fk_driver_profiles_city FOREIGN KEY (city_id) REFERENCES cities(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS driver_service_enablements (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  driver_profile_id BIGINT UNSIGNED NOT NULL,
  service_type_id BIGINT UNSIGNED NOT NULL,
  is_enabled TINYINT(1) NOT NULL DEFAULT 1,
  approved_by_user_id BIGINT UNSIGNED NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_driver_service_enablements (driver_profile_id, service_type_id),
  CONSTRAINT fk_driver_service_driver FOREIGN KEY (driver_profile_id) REFERENCES driver_profiles(id),
  CONSTRAINT fk_driver_service_type FOREIGN KEY (service_type_id) REFERENCES service_types(id),
  CONSTRAINT fk_driver_service_approved_by FOREIGN KEY (approved_by_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS vehicles (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  fleet_owner_id BIGINT UNSIGNED NULL,
  registered_owner_user_id BIGINT UNSIGNED NULL,
  vehicle_type_id BIGINT UNSIGNED NOT NULL,
  vehicle_make_id BIGINT UNSIGNED NULL,
  vehicle_model_id BIGINT UNSIGNED NULL,
  plate_number VARCHAR(50) NOT NULL,
  color VARCHAR(50) NULL,
  year_of_manufacture SMALLINT NULL,
  seats INT NULL,
  fuel_type ENUM('petrol', 'diesel', 'hybrid', 'electric', 'cng', 'other') NOT NULL DEFAULT 'petrol',
  status ENUM('pending', 'active', 'inactive', 'blocked', 'expired') NOT NULL DEFAULT 'pending',
  insurance_expiry_date DATE NULL,
  inspection_expiry_date DATE NULL,
  metadata JSON NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_vehicles_plate_number (plate_number),
  KEY idx_vehicles_fleet_status (fleet_owner_id, status),
  CONSTRAINT fk_vehicles_fleet FOREIGN KEY (fleet_owner_id) REFERENCES fleet_owners(id),
  CONSTRAINT fk_vehicles_owner_user FOREIGN KEY (registered_owner_user_id) REFERENCES users(id),
  CONSTRAINT fk_vehicles_type FOREIGN KEY (vehicle_type_id) REFERENCES vehicle_types(id),
  CONSTRAINT fk_vehicles_make FOREIGN KEY (vehicle_make_id) REFERENCES vehicle_makes(id),
  CONSTRAINT fk_vehicles_model FOREIGN KEY (vehicle_model_id) REFERENCES vehicle_models(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS driver_vehicle_assignments (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  driver_profile_id BIGINT UNSIGNED NOT NULL,
  vehicle_id BIGINT UNSIGNED NOT NULL,
  assigned_by_user_id BIGINT UNSIGNED NULL,
  starts_at DATETIME NOT NULL,
  ends_at DATETIME NULL,
  is_current TINYINT(1) NOT NULL DEFAULT 1,
  notes TEXT NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_driver_vehicle_current (driver_profile_id, vehicle_id, is_current),
  CONSTRAINT fk_driver_vehicle_driver FOREIGN KEY (driver_profile_id) REFERENCES driver_profiles(id),
  CONSTRAINT fk_driver_vehicle_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(id),
  CONSTRAINT fk_driver_vehicle_assigned_by FOREIGN KEY (assigned_by_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS driver_subscriptions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  driver_profile_id BIGINT UNSIGNED NOT NULL,
  subscription_plan_id BIGINT UNSIGNED NOT NULL,
  status ENUM('pending', 'active', 'paused', 'expired', 'cancelled') NOT NULL DEFAULT 'pending',
  amount_paid DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  starts_at DATETIME NOT NULL,
  ends_at DATETIME NOT NULL,
  auto_renew TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_driver_subscriptions_driver_status (driver_profile_id, status),
  CONSTRAINT fk_driver_subscriptions_driver FOREIGN KEY (driver_profile_id) REFERENCES driver_profiles(id),
  CONSTRAINT fk_driver_subscriptions_plan FOREIGN KEY (subscription_plan_id) REFERENCES subscription_plans(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS fleet_subscriptions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  fleet_owner_id BIGINT UNSIGNED NOT NULL,
  subscription_plan_id BIGINT UNSIGNED NOT NULL,
  status ENUM('pending', 'active', 'paused', 'expired', 'cancelled') NOT NULL DEFAULT 'pending',
  amount_paid DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  starts_at DATETIME NOT NULL,
  ends_at DATETIME NOT NULL,
  auto_renew TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_fleet_subscriptions_fleet_status (fleet_owner_id, status),
  CONSTRAINT fk_fleet_subscriptions_fleet FOREIGN KEY (fleet_owner_id) REFERENCES fleet_owners(id),
  CONSTRAINT fk_fleet_subscriptions_plan FOREIGN KEY (subscription_plan_id) REFERENCES subscription_plans(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS wallets (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  wallet_type ENUM('main', 'driver_earnings', 'fleet', 'promo') NOT NULL DEFAULT 'main',
  currency CHAR(3) NOT NULL DEFAULT 'PKR',
  balance DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  hold_balance DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  status ENUM('active', 'frozen', 'closed') NOT NULL DEFAULT 'active',
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_wallets_user_type (user_id, wallet_type),
  CONSTRAINT fk_wallets_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS saved_places (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  label VARCHAR(100) NOT NULL,
  address_line VARCHAR(255) NOT NULL,
  latitude DECIMAL(10,7) NULL,
  longitude DECIMAL(10,7) NULL,
  place_type ENUM('home', 'work', 'school', 'airport', 'other') NOT NULL DEFAULT 'other',
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_saved_places_user (user_id),
  CONSTRAINT fk_saved_places_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS device_tokens (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  platform ENUM('android', 'ios', 'web') NOT NULL,
  device_name VARCHAR(120) NULL,
  token VARCHAR(255) NOT NULL,
  last_used_at DATETIME NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_device_tokens_token (token),
  KEY idx_device_tokens_user (user_id),
  CONSTRAINT fk_device_tokens_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS notification_preferences (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  push_enabled TINYINT(1) NOT NULL DEFAULT 1,
  sms_enabled TINYINT(1) NOT NULL DEFAULT 1,
  email_enabled TINYINT(1) NOT NULL DEFAULT 1,
  marketing_enabled TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_notification_preferences_user (user_id),
  CONSTRAINT fk_notification_preferences_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS pricing_rules (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  city_id BIGINT UNSIGNED NOT NULL,
  service_type_id BIGINT UNSIGNED NOT NULL,
  zone_id BIGINT UNSIGNED NULL,
  vehicle_type_id BIGINT UNSIGNED NULL,
  pricing_model ENUM('fixed', 'metered', 'distance_time', 'hourly', 'daily', 'custom') NOT NULL DEFAULT 'distance_time',
  base_fare DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  per_km_fare DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  per_minute_fare DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  minimum_fare DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  booking_fee DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  waiting_per_minute DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  cancellation_fee DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  platform_fee DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  night_multiplier DECIMAL(6,3) NOT NULL DEFAULT 1.000,
  surge_multiplier DECIMAL(6,3) NOT NULL DEFAULT 1.000,
  effective_from DATETIME NULL,
  effective_to DATETIME NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_pricing_rules_lookup (city_id, service_type_id, zone_id, vehicle_type_id, is_active),
  CONSTRAINT fk_pricing_rules_city FOREIGN KEY (city_id) REFERENCES cities(id),
  CONSTRAINT fk_pricing_rules_service FOREIGN KEY (service_type_id) REFERENCES service_types(id),
  CONSTRAINT fk_pricing_rules_zone FOREIGN KEY (zone_id) REFERENCES zones(id),
  CONSTRAINT fk_pricing_rules_vehicle_type FOREIGN KEY (vehicle_type_id) REFERENCES vehicle_types(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS commission_rules (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  city_id BIGINT UNSIGNED NULL,
  service_type_id BIGINT UNSIGNED NOT NULL,
  subscription_plan_id BIGINT UNSIGNED NULL,
  audience ENUM('independent_driver', 'fleet_owner', 'fleet_driver') NOT NULL DEFAULT 'independent_driver',
  commission_model ENUM('percentage', 'fixed', 'hybrid') NOT NULL DEFAULT 'percentage',
  commission_percent DECIMAL(5,2) NULL,
  fixed_fee DECIMAL(12,2) NULL,
  max_commission DECIMAL(12,2) NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  effective_from DATETIME NULL,
  effective_to DATETIME NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_commission_rules_lookup (city_id, service_type_id, audience, is_active),
  CONSTRAINT fk_commission_rules_city FOREIGN KEY (city_id) REFERENCES cities(id),
  CONSTRAINT fk_commission_rules_service FOREIGN KEY (service_type_id) REFERENCES service_types(id),
  CONSTRAINT fk_commission_rules_plan FOREIGN KEY (subscription_plan_id) REFERENCES subscription_plans(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS bookings (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  booking_reference VARCHAR(40) NOT NULL,
  service_type_id BIGINT UNSIGNED NOT NULL,
  city_id BIGINT UNSIGNED NULL,
  rider_user_id BIGINT UNSIGNED NOT NULL,
  driver_profile_id BIGINT UNSIGNED NULL,
  fleet_owner_id BIGINT UNSIGNED NULL,
  vehicle_id BIGINT UNSIGNED NULL,
  booking_channel ENUM('app', 'web', 'admin') NOT NULL DEFAULT 'app',
  booking_status ENUM('draft', 'pending', 'searching', 'offered', 'accepted', 'arriving', 'in_progress', 'completed', 'cancelled', 'expired', 'failed', 'scheduled') NOT NULL DEFAULT 'pending',
  payment_status ENUM('unpaid', 'authorized', 'paid', 'refunded', 'partial') NOT NULL DEFAULT 'unpaid',
  payment_method ENUM('cash', 'wallet', 'card') NOT NULL DEFAULT 'cash',
  price_type ENUM('estimate', 'negotiated', 'fixed', 'metered', 'subscription') NOT NULL DEFAULT 'estimate',
  estimated_fare DECIMAL(12,2) NULL,
  offered_fare DECIMAL(12,2) NULL,
  counter_fare DECIMAL(12,2) NULL,
  final_fare DECIMAL(12,2) NULL,
  distance_km DECIMAL(10,2) NULL,
  duration_minutes INT NULL,
  pickup_address VARCHAR(255) NULL,
  pickup_latitude DECIMAL(10,7) NULL,
  pickup_longitude DECIMAL(10,7) NULL,
  destination_address VARCHAR(255) NULL,
  destination_latitude DECIMAL(10,7) NULL,
  destination_longitude DECIMAL(10,7) NULL,
  scheduled_for DATETIME NULL,
  requested_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  accepted_at DATETIME NULL,
  driver_arrived_at DATETIME NULL,
  started_at DATETIME NULL,
  completed_at DATETIME NULL,
  cancelled_at DATETIME NULL,
  cancellation_reason VARCHAR(255) NULL,
  notes TEXT NULL,
  metadata JSON NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_bookings_reference (booking_reference),
  KEY idx_bookings_status_service (booking_status, service_type_id),
  KEY idx_bookings_rider_requested (rider_user_id, requested_at),
  KEY idx_bookings_driver_requested (driver_profile_id, requested_at),
  CONSTRAINT fk_bookings_service FOREIGN KEY (service_type_id) REFERENCES service_types(id),
  CONSTRAINT fk_bookings_city FOREIGN KEY (city_id) REFERENCES cities(id),
  CONSTRAINT fk_bookings_rider FOREIGN KEY (rider_user_id) REFERENCES users(id),
  CONSTRAINT fk_bookings_driver FOREIGN KEY (driver_profile_id) REFERENCES driver_profiles(id),
  CONSTRAINT fk_bookings_fleet FOREIGN KEY (fleet_owner_id) REFERENCES fleet_owners(id),
  CONSTRAINT fk_bookings_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS booking_waypoints (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  booking_id BIGINT UNSIGNED NOT NULL,
  stop_order INT NOT NULL,
  label VARCHAR(120) NULL,
  address_line VARCHAR(255) NOT NULL,
  latitude DECIMAL(10,7) NULL,
  longitude DECIMAL(10,7) NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_booking_waypoint_order (booking_id, stop_order),
  CONSTRAINT fk_booking_waypoints_booking FOREIGN KEY (booking_id) REFERENCES bookings(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS booking_offers (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  booking_id BIGINT UNSIGNED NOT NULL,
  driver_profile_id BIGINT UNSIGNED NULL,
  offered_by_user_id BIGINT UNSIGNED NULL,
  offer_source ENUM('rider', 'driver', 'admin', 'system') NOT NULL DEFAULT 'driver',
  amount DECIMAL(12,2) NOT NULL,
  note VARCHAR(255) NULL,
  status ENUM('pending', 'accepted', 'rejected', 'expired', 'withdrawn') NOT NULL DEFAULT 'pending',
  expires_at DATETIME NULL,
  responded_at DATETIME NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_booking_offers_booking_status (booking_id, status),
  CONSTRAINT fk_booking_offers_booking FOREIGN KEY (booking_id) REFERENCES bookings(id),
  CONSTRAINT fk_booking_offers_driver FOREIGN KEY (driver_profile_id) REFERENCES driver_profiles(id),
  CONSTRAINT fk_booking_offers_user FOREIGN KEY (offered_by_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS booking_status_history (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  booking_id BIGINT UNSIGNED NOT NULL,
  old_status VARCHAR(50) NULL,
  new_status VARCHAR(50) NOT NULL,
  changed_by_user_id BIGINT UNSIGNED NULL,
  note VARCHAR(255) NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_booking_status_history_booking (booking_id),
  CONSTRAINT fk_booking_status_history_booking FOREIGN KEY (booking_id) REFERENCES bookings(id),
  CONSTRAINT fk_booking_status_history_user FOREIGN KEY (changed_by_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS booking_messages (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  booking_id BIGINT UNSIGNED NOT NULL,
  sender_user_id BIGINT UNSIGNED NOT NULL,
  message_type ENUM('text', 'system', 'image', 'location') NOT NULL DEFAULT 'text',
  message_body TEXT NULL,
  attachment_url VARCHAR(255) NULL,
  is_read TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_booking_messages_booking (booking_id, created_at),
  CONSTRAINT fk_booking_messages_booking FOREIGN KEY (booking_id) REFERENCES bookings(id),
  CONSTRAINT fk_booking_messages_sender FOREIGN KEY (sender_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ride_tracking_points (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  booking_id BIGINT UNSIGNED NOT NULL,
  driver_profile_id BIGINT UNSIGNED NOT NULL,
  latitude DECIMAL(10,7) NOT NULL,
  longitude DECIMAL(10,7) NOT NULL,
  heading DECIMAL(6,2) NULL,
  speed_kmh DECIMAL(8,2) NULL,
  recorded_at DATETIME NOT NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_ride_tracking_booking_time (booking_id, recorded_at),
  CONSTRAINT fk_ride_tracking_booking FOREIGN KEY (booking_id) REFERENCES bookings(id),
  CONSTRAINT fk_ride_tracking_driver FOREIGN KEY (driver_profile_id) REFERENCES driver_profiles(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ride_bookings (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  booking_id BIGINT UNSIGNED NOT NULL,
  ride_class VARCHAR(80) NULL,
  dispatch_mode ENUM('automatic', 'manual', 'fleet') NOT NULL DEFAULT 'automatic',
  seats_required INT NULL,
  luggage_required INT NULL,
  special_instructions TEXT NULL,
  estimated_distance_km DECIMAL(10,2) NULL,
  estimated_duration_minutes INT NULL,
  actual_distance_km DECIMAL(10,2) NULL,
  actual_duration_minutes INT NULL,
  waiting_minutes INT NOT NULL DEFAULT 0,
  toll_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  airport_terminal VARCHAR(50) NULL,
  is_round_trip TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_ride_bookings_booking (booking_id),
  CONSTRAINT fk_ride_bookings_booking FOREIGN KEY (booking_id) REFERENCES bookings(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS rental_bookings (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  booking_id BIGINT UNSIGNED NOT NULL,
  rental_type ENUM('hourly', 'daily') NOT NULL DEFAULT 'hourly',
  start_at DATETIME NOT NULL,
  end_at DATETIME NOT NULL,
  with_driver TINYINT(1) NOT NULL DEFAULT 1,
  included_km DECIMAL(10,2) NULL,
  extra_km_rate DECIMAL(12,2) NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_rental_bookings_booking (booking_id),
  CONSTRAINT fk_rental_bookings_booking FOREIGN KEY (booking_id) REFERENCES bookings(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS school_bookings (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  booking_id BIGINT UNSIGNED NOT NULL,
  institution_name VARCHAR(191) NOT NULL,
  passenger_name VARCHAR(191) NOT NULL,
  pickup_days VARCHAR(80) NULL,
  dropoff_days VARCHAR(80) NULL,
  guardian_name VARCHAR(191) NULL,
  guardian_phone VARCHAR(30) NULL,
  monthly_fee DECIMAL(12,2) NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_school_bookings_booking (booking_id),
  CONSTRAINT fk_school_bookings_booking FOREIGN KEY (booking_id) REFERENCES bookings(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS food_merchants (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  city_id BIGINT UNSIGNED NULL,
  owner_user_id BIGINT UNSIGNED NULL,
  name VARCHAR(191) NOT NULL,
  slug VARCHAR(191) NOT NULL,
  phone VARCHAR(30) NULL,
  email VARCHAR(191) NULL,
  address_line VARCHAR(255) NULL,
  latitude DECIMAL(10,7) NULL,
  longitude DECIMAL(10,7) NULL,
  status ENUM('pending', 'active', 'inactive', 'blocked') NOT NULL DEFAULT 'pending',
  opening_hours_json JSON NULL,
  commission_percent DECIMAL(5,2) NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_food_merchants_slug (slug),
  CONSTRAINT fk_food_merchants_city FOREIGN KEY (city_id) REFERENCES cities(id),
  CONSTRAINT fk_food_merchants_owner FOREIGN KEY (owner_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS food_items (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  food_merchant_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(191) NOT NULL,
  sku VARCHAR(80) NULL,
  description TEXT NULL,
  price DECIMAL(12,2) NOT NULL,
  is_available TINYINT(1) NOT NULL DEFAULT 1,
  image_url VARCHAR(255) NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_food_items_merchant (food_merchant_id),
  CONSTRAINT fk_food_items_merchant FOREIGN KEY (food_merchant_id) REFERENCES food_merchants(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS food_orders (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  booking_id BIGINT UNSIGNED NOT NULL,
  food_merchant_id BIGINT UNSIGNED NOT NULL,
  subtotal DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  delivery_fee DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  packaging_fee DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  tax_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  special_instructions TEXT NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_food_orders_booking (booking_id),
  CONSTRAINT fk_food_orders_booking FOREIGN KEY (booking_id) REFERENCES bookings(id),
  CONSTRAINT fk_food_orders_merchant FOREIGN KEY (food_merchant_id) REFERENCES food_merchants(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS food_order_items (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  food_order_id BIGINT UNSIGNED NOT NULL,
  food_item_id BIGINT UNSIGNED NOT NULL,
  item_name VARCHAR(191) NOT NULL,
  quantity INT NOT NULL DEFAULT 1,
  unit_price DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  total_price DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  notes VARCHAR(255) NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_food_order_items_order (food_order_id),
  CONSTRAINT fk_food_order_items_order FOREIGN KEY (food_order_id) REFERENCES food_orders(id),
  CONSTRAINT fk_food_order_items_item FOREIGN KEY (food_item_id) REFERENCES food_items(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS courier_orders (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  booking_id BIGINT UNSIGNED NOT NULL,
  receiver_name VARCHAR(191) NOT NULL,
  receiver_phone VARCHAR(30) NOT NULL,
  parcel_type VARCHAR(100) NULL,
  item_description TEXT NULL,
  fragile TINYINT(1) NOT NULL DEFAULT 0,
  weight_kg DECIMAL(8,2) NULL,
  declared_value DECIMAL(12,2) NULL,
  pickup_contact_name VARCHAR(191) NULL,
  pickup_contact_phone VARCHAR(30) NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_courier_orders_booking (booking_id),
  CONSTRAINT fk_courier_orders_booking FOREIGN KEY (booking_id) REFERENCES bookings(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS payments (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  booking_id BIGINT UNSIGNED NOT NULL,
  payer_user_id BIGINT UNSIGNED NOT NULL,
  collected_by_driver_profile_id BIGINT UNSIGNED NULL,
  payment_method ENUM('cash', 'wallet', 'card') NOT NULL DEFAULT 'cash',
  payment_provider VARCHAR(100) NULL,
  provider_reference VARCHAR(191) NULL,
  amount DECIMAL(12,2) NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'PKR',
  status ENUM('pending', 'authorized', 'paid', 'failed', 'refunded', 'partial_refund') NOT NULL DEFAULT 'pending',
  paid_at DATETIME NULL,
  metadata JSON NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_payments_booking_status (booking_id, status),
  CONSTRAINT fk_payments_booking FOREIGN KEY (booking_id) REFERENCES bookings(id),
  CONSTRAINT fk_payments_payer FOREIGN KEY (payer_user_id) REFERENCES users(id),
  CONSTRAINT fk_payments_collected_by FOREIGN KEY (collected_by_driver_profile_id) REFERENCES driver_profiles(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS payouts (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  driver_profile_id BIGINT UNSIGNED NULL,
  fleet_owner_id BIGINT UNSIGNED NULL,
  processed_by_user_id BIGINT UNSIGNED NULL,
  amount DECIMAL(12,2) NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'PKR',
  payout_method ENUM('bank_transfer', 'cash', 'wallet') NOT NULL DEFAULT 'bank_transfer',
  reference_number VARCHAR(100) NULL,
  status ENUM('pending', 'processing', 'paid', 'failed', 'cancelled') NOT NULL DEFAULT 'pending',
  scheduled_for DATETIME NULL,
  paid_at DATETIME NULL,
  notes TEXT NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_payouts_driver_status (driver_profile_id, status),
  KEY idx_payouts_fleet_status (fleet_owner_id, status),
  CONSTRAINT fk_payouts_driver FOREIGN KEY (driver_profile_id) REFERENCES driver_profiles(id),
  CONSTRAINT fk_payouts_fleet FOREIGN KEY (fleet_owner_id) REFERENCES fleet_owners(id),
  CONSTRAINT fk_payouts_processed_by FOREIGN KEY (processed_by_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS wallet_transactions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  wallet_id BIGINT UNSIGNED NOT NULL,
  booking_id BIGINT UNSIGNED NULL,
  payment_id BIGINT UNSIGNED NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  transaction_type ENUM('credit', 'debit', 'hold', 'release', 'adjustment', 'refund', 'payout') NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  balance_after DECIMAL(12,2) NULL,
  reference VARCHAR(100) NULL,
  description VARCHAR(255) NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_wallet_transactions_wallet_time (wallet_id, created_at),
  CONSTRAINT fk_wallet_transactions_wallet FOREIGN KEY (wallet_id) REFERENCES wallets(id),
  CONSTRAINT fk_wallet_transactions_booking FOREIGN KEY (booking_id) REFERENCES bookings(id),
  CONSTRAINT fk_wallet_transactions_payment FOREIGN KEY (payment_id) REFERENCES payments(id),
  CONSTRAINT fk_wallet_transactions_user FOREIGN KEY (created_by_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS driver_documents (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  driver_profile_id BIGINT UNSIGNED NOT NULL,
  document_type ENUM('license', 'cnic', 'profile_photo', 'police_clearance', 'vehicle_registration', 'route_permit', 'other') NOT NULL,
  document_number VARCHAR(100) NULL,
  file_url VARCHAR(255) NOT NULL,
  status ENUM('pending', 'approved', 'rejected', 'expired') NOT NULL DEFAULT 'pending',
  expiry_date DATE NULL,
  reviewed_by_user_id BIGINT UNSIGNED NULL,
  reviewed_at DATETIME NULL,
  rejection_reason VARCHAR(255) NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_driver_documents_driver_status (driver_profile_id, status),
  CONSTRAINT fk_driver_documents_driver FOREIGN KEY (driver_profile_id) REFERENCES driver_profiles(id),
  CONSTRAINT fk_driver_documents_reviewed_by FOREIGN KEY (reviewed_by_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS vehicle_documents (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  vehicle_id BIGINT UNSIGNED NOT NULL,
  document_type ENUM('registration', 'insurance', 'fitness', 'route_permit', 'inspection', 'other') NOT NULL,
  document_number VARCHAR(100) NULL,
  file_url VARCHAR(255) NOT NULL,
  status ENUM('pending', 'approved', 'rejected', 'expired') NOT NULL DEFAULT 'pending',
  expiry_date DATE NULL,
  reviewed_by_user_id BIGINT UNSIGNED NULL,
  reviewed_at DATETIME NULL,
  rejection_reason VARCHAR(255) NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_vehicle_documents_vehicle_status (vehicle_id, status),
  CONSTRAINT fk_vehicle_documents_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(id),
  CONSTRAINT fk_vehicle_documents_reviewed_by FOREIGN KEY (reviewed_by_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS complaints (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  booking_id BIGINT UNSIGNED NULL,
  complainant_user_id BIGINT UNSIGNED NOT NULL,
  against_user_id BIGINT UNSIGNED NULL,
  against_driver_profile_id BIGINT UNSIGNED NULL,
  assigned_admin_user_id BIGINT UNSIGNED NULL,
  complaint_type ENUM('ride', 'driver', 'vehicle', 'payment', 'fleet', 'food', 'courier', 'app', 'other') NOT NULL DEFAULT 'ride',
  priority ENUM('low', 'medium', 'high', 'critical') NOT NULL DEFAULT 'medium',
  status ENUM('open', 'investigating', 'resolved', 'rejected', 'closed') NOT NULL DEFAULT 'open',
  subject VARCHAR(191) NOT NULL,
  description TEXT NOT NULL,
  resolution_notes TEXT NULL,
  resolved_at DATETIME NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_complaints_status_priority (status, priority),
  CONSTRAINT fk_complaints_booking FOREIGN KEY (booking_id) REFERENCES bookings(id),
  CONSTRAINT fk_complaints_complainant FOREIGN KEY (complainant_user_id) REFERENCES users(id),
  CONSTRAINT fk_complaints_against_user FOREIGN KEY (against_user_id) REFERENCES users(id),
  CONSTRAINT fk_complaints_against_driver FOREIGN KEY (against_driver_profile_id) REFERENCES driver_profiles(id),
  CONSTRAINT fk_complaints_assigned_admin FOREIGN KEY (assigned_admin_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ratings_reviews (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  booking_id BIGINT UNSIGNED NOT NULL,
  reviewer_user_id BIGINT UNSIGNED NOT NULL,
  reviewee_user_id BIGINT UNSIGNED NULL,
  driver_profile_id BIGINT UNSIGNED NULL,
  stars TINYINT UNSIGNED NOT NULL,
  review_context ENUM('rider_to_driver', 'driver_to_rider', 'fleet_to_driver', 'admin_audit') NOT NULL DEFAULT 'rider_to_driver',
  review_text TEXT NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_ratings_reviews_booking (booking_id),
  KEY idx_ratings_reviews_driver (driver_profile_id),
  CONSTRAINT fk_ratings_reviews_booking FOREIGN KEY (booking_id) REFERENCES bookings(id),
  CONSTRAINT fk_ratings_reviews_reviewer FOREIGN KEY (reviewer_user_id) REFERENCES users(id),
  CONSTRAINT fk_ratings_reviews_reviewee FOREIGN KEY (reviewee_user_id) REFERENCES users(id),
  CONSTRAINT fk_ratings_reviews_driver FOREIGN KEY (driver_profile_id) REFERENCES driver_profiles(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS admin_audit_logs (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  admin_user_id BIGINT UNSIGNED NOT NULL,
  action VARCHAR(120) NOT NULL,
  entity_type VARCHAR(120) NOT NULL,
  entity_id BIGINT UNSIGNED NULL,
  note TEXT NULL,
  before_json JSON NULL,
  after_json JSON NULL,
  ip_address VARCHAR(45) NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_admin_audit_logs_admin_time (admin_user_id, created_at),
  CONSTRAINT fk_admin_audit_logs_admin FOREIGN KEY (admin_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET foreign_key_checks = 1;
