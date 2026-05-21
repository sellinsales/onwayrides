import 'package:flutter/material.dart';

enum ServiceType {
  rideShare,
  taxi,
  bikeTaxi,
  rickshawTaxi,
  rentCar,
  cityToCity,
  schoolOffice,
  foodDelivery,
  courier,
  airport,
  prebooking,
}

class OnWayService {
  const OnWayService({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.imageAsset,
    required this.icon,
    required this.eta,
    this.negotiable = false,
  });

  final ServiceType type;
  final String title;
  final String subtitle;
  final String imageAsset;
  final IconData icon;
  final String eta;
  final bool negotiable;
}

class FareOption {
  const FareOption({
    required this.title,
    required this.capacity,
    required this.eta,
    required this.priceLabel,
    this.recommended = false,
    this.negotiable = false,
  });

  final String title;
  final String capacity;
  final String eta;
  final String priceLabel;
  final bool recommended;
  final bool negotiable;
}

class DriverProfile {
  const DriverProfile({
    required this.name,
    required this.rating,
    required this.vehicle,
    required this.plate,
    required this.phone,
    required this.distanceAway,
    required this.eta,
    required this.avatarAsset,
  });

  final String name;
  final String rating;
  final String vehicle;
  final String plate;
  final String phone;
  final String distanceAway;
  final String eta;
  final String avatarAsset;
}

class ActiveTrip {
  const ActiveTrip({
    required this.serviceTitle,
    required this.pickup,
    required this.destination,
    required this.statusLine,
    required this.routeLine,
    required this.paymentLabel,
    required this.fareLabel,
    required this.driver,
  });

  final String serviceTitle;
  final String pickup;
  final String destination;
  final String statusLine;
  final String routeLine;
  final String paymentLabel;
  final String fareLabel;
  final DriverProfile driver;
}

class TripHistoryItem {
  const TripHistoryItem({
    required this.title,
    required this.dateLabel,
    required this.route,
    required this.amount,
    required this.status,
  });

  final String title;
  final String dateLabel;
  final String route;
  final String amount;
  final String status;
}

class DriverStat {
  const DriverStat({
    required this.label,
    required this.value,
    required this.delta,
  });

  final String label;
  final String value;
  final String delta;
}

class DriverRequest {
  const DriverRequest({
    required this.serviceTitle,
    required this.riderName,
    required this.pickup,
    required this.dropoff,
    required this.fareLabel,
    required this.distanceLabel,
    required this.paymentLabel,
    required this.canCounter,
  });

  final String serviceTitle;
  final String riderName;
  final String pickup;
  final String dropoff;
  final String fareLabel;
  final String distanceLabel;
  final String paymentLabel;
  final bool canCounter;
}

class FleetMetric {
  const FleetMetric({
    required this.label,
    required this.value,
    required this.delta,
  });

  final String label;
  final String value;
  final String delta;
}

class FleetDriver {
  const FleetDriver({
    required this.name,
    required this.status,
    required this.rating,
    required this.vehicle,
    required this.services,
  });

  final String name;
  final String status;
  final String rating;
  final String vehicle;
  final List<String> services;
}

class FleetVehicle {
  const FleetVehicle({
    required this.plate,
    required this.type,
    required this.assignedDriver,
    required this.status,
  });

  final String plate;
  final String type;
  final String assignedDriver;
  final String status;
}
