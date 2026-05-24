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
}
