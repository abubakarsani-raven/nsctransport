export class UserUpdatedEvent {
  constructor() {}
}

export class RequestUpdatedEvent {
  constructor() {}
}

export class TripUpdatedEvent {
  constructor(public tripId?: string) {}
}

export class VehicleUpdatedEvent {
  constructor(public vehicleId?: string) {}
}

export class NotificationUpdatedEvent {
  constructor(public userId: string, public notification?: any, public unread?: number) {}
}

export class HistoryUpdatedEvent {
  constructor(public requestId: string) {}
}

export class LocationUpdatedEvent {
  constructor(
    public tripId: string,
    public driverId: string,
    public location: { lat: number; lng: number; timestamp: Date },
  ) {}
}

