-- OnWay Rides baseline seed data
-- Import this file after 01_onwayrides_schema.sql

SET NAMES utf8mb4;
SET time_zone = '+00:00';
SET foreign_key_checks = 0;

USE `onwayrides_onwayrides`;

INSERT INTO system_settings (`group`, `key`, value_text, value_json, is_public)
VALUES
  ('general', 'app_name', 'OnWay Rides', NULL, 1),
  ('general', 'support_email', 'support@onwayrides.com', NULL, 1),
  ('general', 'support_phone', '+92-300-0000000', NULL, 1),
  ('general', 'default_currency', 'PKR', NULL, 1),
  ('general', 'default_country_code', '+92', NULL, 1),
  ('platform', 'enabled_modules', NULL, JSON_ARRAY('ride', 'delivery', 'rental', 'food', 'school', 'airport', 'prebooking'), 1),
  ('maps', 'provider', 'google_maps', NULL, 0)
ON DUPLICATE KEY UPDATE
  value_text = VALUES(value_text),
  value_json = VALUES(value_json),
  is_public = VALUES(is_public),
  updated_at = CURRENT_TIMESTAMP;

INSERT INTO cities (id, name, slug, province, country_code, latitude, longitude, is_enabled)
VALUES
  (1, 'Lahore', 'lahore', 'Punjab', 'PK', 31.5204000, 74.3587000, 1),
  (2, 'Karachi', 'karachi', 'Sindh', 'PK', 24.8607000, 67.0011000, 1),
  (3, 'Islamabad', 'islamabad', 'Islamabad Capital Territory', 'PK', 33.6844000, 73.0479000, 1),
  (4, 'Rawalpindi', 'rawalpindi', 'Punjab', 'PK', 33.5651000, 73.0169000, 1)
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  province = VALUES(province),
  country_code = VALUES(country_code),
  latitude = VALUES(latitude),
  longitude = VALUES(longitude),
  is_enabled = VALUES(is_enabled),
  updated_at = CURRENT_TIMESTAMP;

INSERT INTO service_types (
  id, name, slug, category, description, supports_negotiation, supports_scheduling, supports_driver_mode, is_active, sort_order
) VALUES
  (1, 'Ride', 'ride', 'ride', 'Standard city ride bookings.', 0, 1, 1, 1, 10),
  (2, 'Courier Delivery', 'courier', 'delivery', 'Bike and small parcel delivery.', 0, 1, 1, 1, 20),
  (3, 'Rental', 'rental', 'rental', 'Hourly and daily car rentals.', 0, 1, 1, 1, 30),
  (4, 'Food Delivery', 'food', 'food', 'Restaurant and meal delivery.', 0, 1, 1, 1, 40),
  (5, 'School Commute', 'school', 'school', 'Recurring school transport service.', 0, 1, 1, 1, 50),
  (6, 'Airport Transfer', 'airport', 'airport', 'Airport pickup and drop-off service.', 0, 1, 1, 1, 60),
  (7, 'Pre-Booking', 'prebooking', 'prebooking', 'Scheduled trips booked in advance.', 0, 1, 1, 1, 70)
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  category = VALUES(category),
  description = VALUES(description),
  supports_negotiation = VALUES(supports_negotiation),
  supports_scheduling = VALUES(supports_scheduling),
  supports_driver_mode = VALUES(supports_driver_mode),
  is_active = VALUES(is_active),
  sort_order = VALUES(sort_order),
  updated_at = CURRENT_TIMESTAMP;

INSERT INTO city_service_settings (
  id, city_id, service_type_id, is_enabled, supports_negotiation, supports_scheduling, base_eta_minutes, min_distance_km, max_distance_km
) VALUES
  (1, 1, 1, 1, 0, 1, 6, 1.00, 40.00),
  (2, 1, 2, 1, 0, 1, 12, 1.00, 20.00),
  (3, 1, 3, 1, 0, 1, 25, 2.00, 250.00),
  (4, 1, 6, 1, 0, 1, 20, 5.00, 80.00),
  (5, 2, 1, 1, 0, 1, 8, 1.00, 45.00),
  (6, 2, 2, 1, 0, 1, 14, 1.00, 20.00),
  (7, 3, 1, 1, 0, 1, 7, 1.00, 35.00),
  (8, 4, 1, 1, 0, 1, 7, 1.00, 35.00)
ON DUPLICATE KEY UPDATE
  is_enabled = VALUES(is_enabled),
  supports_negotiation = VALUES(supports_negotiation),
  supports_scheduling = VALUES(supports_scheduling),
  base_eta_minutes = VALUES(base_eta_minutes),
  min_distance_km = VALUES(min_distance_km),
  max_distance_km = VALUES(max_distance_km),
  updated_at = CURRENT_TIMESTAMP;

INSERT INTO subscription_plans (
  id, code, name, audience, billing_cycle, amount, currency, lower_commission_percent, max_active_vehicles, max_active_drivers, benefits_json, is_active
) VALUES
  (1, 'DRV-WEEKLY', 'Driver Weekly', 'driver', 'weekly', 1500.00, 'PKR', 12.50, NULL, NULL, JSON_ARRAY('Lower commission than default', 'Priority support'), 1),
  (2, 'DRV-MONTHLY', 'Driver Monthly', 'driver', 'monthly', 5000.00, 'PKR', 10.00, NULL, NULL, JSON_ARRAY('Lower commission', 'Monthly savings', 'Priority support'), 1),
  (3, 'FLEET-BASIC', 'Fleet Basic', 'fleet_owner', 'monthly', 12000.00, 'PKR', NULL, 10, 20, JSON_ARRAY('Up to 10 active vehicles', 'Up to 20 active drivers'), 1),
  (4, 'FLEET-PRO', 'Fleet Pro', 'fleet_owner', 'monthly', 25000.00, 'PKR', NULL, 50, 100, JSON_ARRAY('Higher fleet capacity', 'Priority support', 'Custom commission options'), 1)
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  audience = VALUES(audience),
  billing_cycle = VALUES(billing_cycle),
  amount = VALUES(amount),
  currency = VALUES(currency),
  lower_commission_percent = VALUES(lower_commission_percent),
  max_active_vehicles = VALUES(max_active_vehicles),
  max_active_drivers = VALUES(max_active_drivers),
  benefits_json = VALUES(benefits_json),
  is_active = VALUES(is_active),
  updated_at = CURRENT_TIMESTAMP;

INSERT INTO vehicle_categories (id, name, slug, icon_name)
VALUES
  (1, 'Car', 'car', 'car'),
  (2, 'Bike', 'bike', 'bike'),
  (3, 'Rickshaw', 'rickshaw', 'rickshaw'),
  (4, 'Van', 'van', 'van')
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  icon_name = VALUES(icon_name),
  updated_at = CURRENT_TIMESTAMP;

INSERT INTO vehicle_types (id, vehicle_category_id, name, slug, seats, luggage_capacity, is_active)
VALUES
  (1, 1, 'Economy Car', 'economy-car', 4, 2, 1),
  (2, 2, 'Bike', 'bike-standard', 1, 0, 1),
  (3, 3, 'Auto Rickshaw', 'auto-rickshaw', 3, 0, 1),
  (4, 4, 'Mini Van', 'mini-van', 7, 6, 1),
  (5, 1, 'Executive Car', 'executive-car', 4, 3, 1)
ON DUPLICATE KEY UPDATE
  vehicle_category_id = VALUES(vehicle_category_id),
  name = VALUES(name),
  seats = VALUES(seats),
  luggage_capacity = VALUES(luggage_capacity),
  is_active = VALUES(is_active),
  updated_at = CURRENT_TIMESTAMP;

INSERT INTO vehicle_makes (id, name, is_active)
VALUES
  (1, 'Toyota', 1),
  (2, 'Honda', 1),
  (3, 'Suzuki', 1),
  (4, 'United', 1)
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  is_active = VALUES(is_active),
  updated_at = CURRENT_TIMESTAMP;

INSERT INTO vehicle_models (id, vehicle_make_id, name, is_active)
VALUES
  (1, 1, 'Corolla', 1),
  (2, 2, 'City', 1),
  (3, 3, 'Alto', 1),
  (4, 2, 'CD 70', 1),
  (5, 4, 'Auto Rickshaw', 1),
  (6, 1, 'Hiace', 1)
ON DUPLICATE KEY UPDATE
  vehicle_make_id = VALUES(vehicle_make_id),
  name = VALUES(name),
  is_active = VALUES(is_active),
  updated_at = CURRENT_TIMESTAMP;

INSERT INTO pricing_rules (
  id, city_id, service_type_id, zone_id, vehicle_type_id, pricing_model,
  base_fare, per_km_fare, per_minute_fare, minimum_fare, booking_fee,
  waiting_per_minute, cancellation_fee, platform_fee, night_multiplier,
  surge_multiplier, effective_from, effective_to, is_active
) VALUES
  (1, 1, 1, NULL, 1, 'distance_time', 180.00, 32.00, 4.00, 250.00, 20.00, 3.00, 100.00, 25.00, 1.150, 1.000, NOW(), NULL, 1),
  (2, 1, 2, NULL, 2, 'distance_time', 120.00, 22.00, 3.00, 170.00, 15.00, 2.00, 80.00, 15.00, 1.100, 1.000, NOW(), NULL, 1),
  (3, 1, 6, NULL, 5, 'fixed', 950.00, 0.00, 0.00, 950.00, 40.00, 0.00, 250.00, 50.00, 1.000, 1.000, NOW(), NULL, 1),
  (4, 2, 1, NULL, 1, 'distance_time', 200.00, 34.00, 4.00, 280.00, 20.00, 3.00, 100.00, 25.00, 1.150, 1.000, NOW(), NULL, 1),
  (5, 3, 1, NULL, 1, 'distance_time', 190.00, 30.00, 4.00, 260.00, 20.00, 3.00, 100.00, 25.00, 1.100, 1.000, NOW(), NULL, 1)
ON DUPLICATE KEY UPDATE
  city_id = VALUES(city_id),
  service_type_id = VALUES(service_type_id),
  vehicle_type_id = VALUES(vehicle_type_id),
  pricing_model = VALUES(pricing_model),
  base_fare = VALUES(base_fare),
  per_km_fare = VALUES(per_km_fare),
  per_minute_fare = VALUES(per_minute_fare),
  minimum_fare = VALUES(minimum_fare),
  booking_fee = VALUES(booking_fee),
  waiting_per_minute = VALUES(waiting_per_minute),
  cancellation_fee = VALUES(cancellation_fee),
  platform_fee = VALUES(platform_fee),
  night_multiplier = VALUES(night_multiplier),
  surge_multiplier = VALUES(surge_multiplier),
  effective_from = VALUES(effective_from),
  effective_to = VALUES(effective_to),
  is_active = VALUES(is_active),
  updated_at = CURRENT_TIMESTAMP;

INSERT INTO commission_rules (
  id, city_id, service_type_id, subscription_plan_id, audience, commission_model,
  commission_percent, fixed_fee, max_commission, is_active, effective_from, effective_to
) VALUES
  (1, NULL, 1, NULL, 'independent_driver', 'percentage', 18.00, NULL, NULL, 1, NOW(), NULL),
  (2, NULL, 1, 1, 'independent_driver', 'percentage', 12.50, NULL, NULL, 1, NOW(), NULL),
  (3, NULL, 1, 2, 'independent_driver', 'percentage', 10.00, NULL, NULL, 1, NOW(), NULL),
  (4, NULL, 1, NULL, 'fleet_owner', 'percentage', 8.00, NULL, NULL, 1, NOW(), NULL),
  (5, NULL, 2, NULL, 'independent_driver', 'percentage', 15.00, NULL, NULL, 1, NOW(), NULL)
ON DUPLICATE KEY UPDATE
  city_id = VALUES(city_id),
  service_type_id = VALUES(service_type_id),
  subscription_plan_id = VALUES(subscription_plan_id),
  audience = VALUES(audience),
  commission_model = VALUES(commission_model),
  commission_percent = VALUES(commission_percent),
  fixed_fee = VALUES(fixed_fee),
  max_commission = VALUES(max_commission),
  is_active = VALUES(is_active),
  effective_from = VALUES(effective_from),
  effective_to = VALUES(effective_to),
  updated_at = CURRENT_TIMESTAMP;

INSERT INTO users (
  id, firebase_uid, full_name, first_name, last_name, email, phone, country_code,
  password_hash, role, status, avatar_url, national_id_number, referral_code,
  referred_by_user_id, email_verified_at, phone_verified_at, last_login_at, metadata
) VALUES
  (
    1, NULL, 'OnWay Admin', 'OnWay', 'Admin', 'admin@onwayrides.com', '+923000000001', '+92',
    '$2y$12$eqKwsKx9xcgdGaBpKfLh9OcZ1.R4D4NHWKLER.zDLWqRymqWsKSbK',
    'admin', 'active', NULL, NULL, 'ONWAYADMIN', NULL, NOW(), NOW(), NULL,
    JSON_OBJECT('seeded', TRUE, 'notes', 'Initial platform administrator')
  )
ON DUPLICATE KEY UPDATE
  full_name = VALUES(full_name),
  first_name = VALUES(first_name),
  last_name = VALUES(last_name),
  email = VALUES(email),
  phone = VALUES(phone),
  country_code = VALUES(country_code),
  password_hash = VALUES(password_hash),
  role = VALUES(role),
  status = VALUES(status),
  referral_code = VALUES(referral_code),
  email_verified_at = VALUES(email_verified_at),
  phone_verified_at = VALUES(phone_verified_at),
  metadata = VALUES(metadata),
  updated_at = CURRENT_TIMESTAMP;

INSERT INTO wallets (id, user_id, wallet_type, currency, balance, hold_balance, status)
VALUES
  (1, 1, 'main', 'PKR', 0.00, 0.00, 'active')
ON DUPLICATE KEY UPDATE
  currency = VALUES(currency),
  balance = VALUES(balance),
  hold_balance = VALUES(hold_balance),
  status = VALUES(status),
  updated_at = CURRENT_TIMESTAMP;

INSERT INTO notification_preferences (id, user_id, push_enabled, sms_enabled, email_enabled, marketing_enabled)
VALUES
  (1, 1, 1, 1, 1, 0)
ON DUPLICATE KEY UPDATE
  push_enabled = VALUES(push_enabled),
  sms_enabled = VALUES(sms_enabled),
  email_enabled = VALUES(email_enabled),
  marketing_enabled = VALUES(marketing_enabled),
  updated_at = CURRENT_TIMESTAMP;

SET foreign_key_checks = 1;
