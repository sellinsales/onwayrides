import 'package:flutter/material.dart';

import 'onway_models.dart';

class OnWayMockData {
  static const services = <OnWayService>[
    OnWayService(
      type: ServiceType.rideShare,
      title: 'Taxi',
      subtitle: 'Everyday local rides',
      imageAsset: 'assets/services/ride.png',
      icon: Icons.local_taxi_rounded,
      eta: '2 min',
      negotiable: true,
    ),
    OnWayService(
      type: ServiceType.bikeTaxi,
      title: 'Bike Taxi',
      subtitle: 'Fast & low cost',
      imageAsset: 'assets/services/bike.png',
      icon: Icons.two_wheeler_rounded,
      eta: '3 min',
      negotiable: true,
    ),
    OnWayService(
      type: ServiceType.rickshawTaxi,
      title: 'Rickshaw',
      subtitle: 'Local short hops',
      imageAsset: 'assets/services/rickshaw.png',
      icon: Icons.electric_rickshaw_rounded,
      eta: '5 min',
      negotiable: true,
    ),
    OnWayService(
      type: ServiceType.rentCar,
      title: 'Rent a Car',
      subtitle: 'Hourly or daily',
      imageAsset: 'assets/services/rent.png',
      icon: Icons.directions_car_filled_rounded,
      eta: '15 min',
    ),
    OnWayService(
      type: ServiceType.foodDelivery,
      title: 'Food',
      subtitle: 'Fresh nearby meals',
      imageAsset: 'assets/services/food.png',
      icon: Icons.restaurant_menu_rounded,
      eta: '20 min',
    ),
    OnWayService(
      type: ServiceType.courier,
      title: 'Courier',
      subtitle: 'TapTap-style delivery',
      imageAsset: 'assets/services/courier.png',
      icon: Icons.inventory_2_rounded,
      eta: '12 min',
      negotiable: true,
    ),
    OnWayService(
      type: ServiceType.cityToCity,
      title: 'City to City',
      subtitle: 'Intercity travel',
      imageAsset: 'assets/services/city.png',
      icon: Icons.route_rounded,
      eta: '30 min',
    ),
    OnWayService(
      type: ServiceType.schoolOffice,
      title: 'School & Office',
      subtitle: 'Recurring pickups',
      imageAsset: 'assets/services/school.png',
      icon: Icons.school_rounded,
      eta: '6 min',
    ),
    OnWayService(
      type: ServiceType.airport,
      title: 'Airport',
      subtitle: 'Terminal transfers',
      imageAsset: 'assets/services/airport.png',
      icon: Icons.flight_takeoff_rounded,
      eta: '18 min',
    ),
    OnWayService(
      type: ServiceType.prebooking,
      title: 'Prebooking',
      subtitle: 'Schedule ahead',
      imageAsset: 'assets/services/prebooking.png',
      icon: Icons.schedule_rounded,
      eta: 'Plan now',
    ),
  ];

  static const fareOptions = <FareOption>[
    FareOption(
      title: 'OnWay Go',
      capacity: '1-4 seats',
      eta: '3 min',
      priceLabel: 'PKR 620',
      recommended: true,
      negotiable: true,
    ),
    FareOption(
      title: 'OnWay Bike',
      capacity: '1 seat',
      eta: '2 min',
      priceLabel: 'PKR 240',
      negotiable: true,
    ),
    FareOption(
      title: 'OnWay XL',
      capacity: '1-6 seats',
      eta: '6 min',
      priceLabel: 'PKR 980',
    ),
  ];

  static const savedPlaces = <OnWayPlaceSuggestion>[
    OnWayPlaceSuggestion(
      title: 'Home',
      addressLine: 'Johar Town, Lahore',
      icon: Icons.home_rounded,
      badge: 'Saved',
      isSaved: true,
    ),
    OnWayPlaceSuggestion(
      title: 'Office',
      addressLine: 'Gulberg Main Boulevard, Lahore',
      icon: Icons.business_center_rounded,
      badge: 'Saved',
      isSaved: true,
    ),
    OnWayPlaceSuggestion(
      title: 'Airport',
      addressLine: 'Allama Iqbal International Airport',
      icon: Icons.flight_takeoff_rounded,
      badge: 'Saved',
      isSaved: true,
    ),
    OnWayPlaceSuggestion(
      title: 'School',
      addressLine: 'Beaconhouse Canal Campus',
      icon: Icons.school_rounded,
      badge: 'Saved',
      isSaved: true,
    ),
  ];

  static const recentPlaces = <OnWayPlaceSuggestion>[
    OnWayPlaceSuggestion(
      title: 'Packages Mall',
      addressLine: 'Walton Road, Lahore',
      icon: Icons.local_mall_rounded,
      badge: 'Recent',
    ),
    OnWayPlaceSuggestion(
      title: 'Emporium Mall',
      addressLine: 'Abdul Haque Road, Lahore',
      icon: Icons.storefront_rounded,
      badge: 'Recent',
    ),
    OnWayPlaceSuggestion(
      title: 'Liberty Roundabout',
      addressLine: 'Gulberg III, Lahore',
      icon: Icons.place_rounded,
      badge: 'Recent',
    ),
    OnWayPlaceSuggestion(
      title: 'Rawalakot Bypass',
      addressLine: 'Poonch, Azad Kashmir',
      icon: Icons.route_rounded,
      badge: 'Recent',
    ),
  ];

  static const locationSuggestions = <OnWayPlaceSuggestion>[
    OnWayPlaceSuggestion(
      title: 'Current location',
      addressLine: 'Use device GPS pin',
      icon: Icons.my_location_rounded,
      badge: 'GPS',
    ),
    OnWayPlaceSuggestion(
      title: 'Muzaffarabad City',
      addressLine: 'Old Secretariat Road, Azad Kashmir',
      icon: Icons.location_city_rounded,
      badge: 'AJK',
    ),
    OnWayPlaceSuggestion(
      title: 'Mirpur City',
      addressLine: 'Sector F-1, Azad Kashmir',
      icon: Icons.location_city_rounded,
      badge: 'AJK',
    ),
    OnWayPlaceSuggestion(
      title: 'Bhimber Chowk',
      addressLine: 'Bhimber, Azad Kashmir',
      icon: Icons.location_city_rounded,
      badge: 'AJK',
    ),
    OnWayPlaceSuggestion(
      title: 'Daewoo Terminal',
      addressLine: 'Thokar Niaz Baig, Lahore',
      icon: Icons.directions_bus_rounded,
      badge: 'Terminal',
    ),
    OnWayPlaceSuggestion(
      title: 'LGS 55 Main',
      addressLine: 'Gulberg Lahore',
      icon: Icons.school_rounded,
      badge: 'School',
    ),
    OnWayPlaceSuggestion(
      title: 'Cargo Market',
      addressLine: 'Badami Bagh, Lahore',
      icon: Icons.local_shipping_rounded,
      badge: 'Courier',
    ),
  ];

  static const riderContextualSuggestions = <OnWayContextualSuggestion>[
    OnWayContextualSuggestion(
      title: 'Airport transfer available',
      description:
          'If you are heading to a terminal or booking for family arrival, switch to the airport flow for luggage-ready vehicles.',
      icon: Icons.flight_takeoff_rounded,
      serviceType: ServiceType.airport,
      ctaLabel: 'Switch to airport',
    ),
    OnWayContextualSuggestion(
      title: 'Courier instead of rider trip?',
      description:
          'Sending documents or a parcel is faster through the courier flow than a normal taxi booking.',
      icon: Icons.inventory_2_rounded,
      serviceType: ServiceType.courier,
      ctaLabel: 'Use courier',
    ),
    OnWayContextualSuggestion(
      title: 'Need a rental for the day?',
      description:
          'Long waits, meetings, or family trips are easier in the rental flow with hourly and daily options.',
      icon: Icons.directions_car_filled_rounded,
      serviceType: ServiceType.rentCar,
      ctaLabel: 'Open rentals',
    ),
    OnWayContextualSuggestion(
      title: 'Set a recurring school route',
      description:
          'If this is a repeated pickup, save time by switching to the school and office route flow.',
      icon: Icons.school_rounded,
      serviceType: ServiceType.schoolOffice,
      ctaLabel: 'Use school flow',
    ),
  ];

  static const driver = DriverProfile(
    name: 'Ali Raza',
    rating: '4.9',
    vehicle: 'Toyota Yaris - Black',
    plate: 'LEA 2475',
    phone: '+92 300 1234567',
    distanceAway: '1.2 km away',
    eta: 'Arriving in 3 min',
    avatarAsset: 'assets/showcase/driver_profile.png',
  );

  static const activeTrip = ActiveTrip(
    serviceTitle: 'OnWay Go',
    pickup: 'Johar Town, Lahore',
    destination: 'Packages Mall, Lahore',
    statusLine: 'Driver is on the way',
    routeLine: 'Pickup at Allah Hoo Chowk, drop at Main Boulevard',
    paymentLabel: 'Cash payment',
    fareLabel: 'PKR 620',
    driver: driver,
  );

  static const tripHistory = <TripHistoryItem>[
    TripHistoryItem(
      title: 'Airport Booking',
      dateLabel: 'Today, 9:15 AM',
      route: 'DHA Phase 6 -> Allama Iqbal Airport',
      amount: 'PKR 1,450',
      status: 'Completed',
    ),
    TripHistoryItem(
      title: 'Food Delivery',
      dateLabel: 'Yesterday, 7:40 PM',
      route: 'MM Alam Road -> Model Town',
      amount: 'PKR 540',
      status: 'Delivered',
    ),
    TripHistoryItem(
      title: 'School Pick & Drop',
      dateLabel: 'Mon, 7:00 AM',
      route: 'Bahria Town -> Beaconhouse',
      amount: 'PKR 7,800',
      status: 'Scheduled',
    ),
  ];

  static const driverStats = <DriverStat>[
    DriverStat(label: 'Today earnings', value: 'PKR 8,420', delta: '+12%'),
    DriverStat(label: 'Trips today', value: '14', delta: '+3'),
    DriverStat(label: 'Available requests', value: '06', delta: 'Live'),
    DriverStat(label: 'Wallet balance', value: 'PKR 3,260', delta: 'Ready'),
  ];

  static const driverRequests = <DriverRequest>[
    DriverRequest(
      serviceTitle: 'Taxi',
      riderName: 'Usman Tariq',
      pickup: 'Emporium Mall Gate 2',
      dropoff: 'Gulberg Main Market',
      fareLabel: 'PKR 710',
      distanceLabel: '8.4 km',
      paymentLabel: 'Cash',
      canCounter: true,
    ),
    DriverRequest(
      serviceTitle: 'Courier',
      riderName: 'Sana Malik',
      pickup: 'Liberty Roundabout',
      dropoff: 'Model Town C Block',
      fareLabel: 'PKR 420',
      distanceLabel: '5.1 km',
      paymentLabel: 'Wallet',
      canCounter: true,
    ),
    DriverRequest(
      serviceTitle: 'School & Office',
      riderName: 'Hassan Ali',
      pickup: 'DHA Phase 5',
      dropoff: 'LGS 55 Main',
      fareLabel: 'PKR 14,000 / month',
      distanceLabel: 'Recurring',
      paymentLabel: 'Cash',
      canCounter: false,
    ),
  ];

  static const fleetMetrics = <FleetMetric>[
    FleetMetric(label: 'Total drivers', value: '28', delta: '+2 this week'),
    FleetMetric(label: 'Active drivers', value: '19', delta: '68% online'),
    FleetMetric(label: 'Total vehicles', value: '24', delta: '2 in review'),
    FleetMetric(label: 'Active rides', value: '11', delta: 'Live'),
    FleetMetric(label: 'Earnings', value: 'PKR 412k', delta: 'This month'),
    FleetMetric(label: 'Payouts', value: 'PKR 263k', delta: 'Processed'),
    FleetMetric(label: 'Complaints', value: '03', delta: 'Needs action'),
    FleetMetric(label: 'Driver rating', value: '4.7', delta: 'Fleet avg'),
  ];

  static const fleetDrivers = <FleetDriver>[
    FleetDriver(
      name: 'Ahmed Nawaz',
      status: 'Online',
      rating: '4.9',
      vehicle: 'Honda City - LEX 2093',
      services: ['Taxi', 'Airport', 'City to City'],
    ),
    FleetDriver(
      name: 'Bilal Hussain',
      status: 'Busy',
      rating: '4.8',
      vehicle: 'Suzuki Every - LEB 8871',
      services: ['Courier', 'School & Office'],
    ),
    FleetDriver(
      name: 'Shahzaib Khan',
      status: 'Offline',
      rating: '4.6',
      vehicle: 'Rickshaw - LRK 116',
      services: ['Rickshaw', 'Bike Taxi'],
    ),
  ];

  static const fleetVehicles = <FleetVehicle>[
    FleetVehicle(
      plate: 'LEA 2475',
      type: 'Toyota Yaris',
      assignedDriver: 'Ahmed Nawaz',
      status: 'Active',
    ),
    FleetVehicle(
      plate: 'LEB 8871',
      type: 'Suzuki Every',
      assignedDriver: 'Bilal Hussain',
      status: 'Dispatch',
    ),
    FleetVehicle(
      plate: 'LRK 116',
      type: 'Loader Rickshaw',
      assignedDriver: 'Shahzaib Khan',
      status: 'Offline',
    ),
  ];

  static OnWayService serviceForType(ServiceType type) {
    return services.firstWhere((service) => service.type == type);
  }

  static ActiveTrip tripForService(OnWayService service) {
    return ActiveTrip(
      serviceTitle: service.title,
      pickup: 'Johar Town, Lahore',
      destination: service.type == ServiceType.airport
          ? 'Allama Iqbal International Airport'
          : 'Packages Mall, Lahore',
      statusLine: service.type == ServiceType.prebooking
          ? 'Trip scheduled and awaiting dispatch'
          : 'Driver confirmed and heading to pickup',
      routeLine: 'Pickup at Allah Hoo Chowk, route optimized for traffic',
      paymentLabel: 'Cash payment',
      fareLabel: fareOptions.first.priceLabel,
      driver: driver,
    );
  }

  static List<OnWayContextualSuggestion> contextualSuggestionsFor(
    String routeText,
  ) {
    final normalized = routeText.toLowerCase();
    final matches = <OnWayContextualSuggestion>[];

    if (normalized.contains('airport') || normalized.contains('terminal')) {
      matches.add(riderContextualSuggestions.first);
    }
    if (normalized.contains('school') ||
        normalized.contains('campus') ||
        normalized.contains('office')) {
      matches.add(riderContextualSuggestions[3]);
    }
    if (normalized.contains('cargo') ||
        normalized.contains('market') ||
        normalized.contains('parcel')) {
      matches.add(riderContextualSuggestions[1]);
    }

    matches.add(riderContextualSuggestions[2]);

    final unique = <ServiceType>{};
    return matches.where((item) => unique.add(item.serviceType)).toList();
  }
}
