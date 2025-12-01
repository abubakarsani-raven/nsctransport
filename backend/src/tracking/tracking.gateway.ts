import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { UseGuards } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { TripsService } from '../trips/trips.service';
import { VehiclesService } from '../vehicles/vehicles.service';
import { UsersService } from '../users/users.service';
import { VehicleRequestService } from '../requests/vehicle/vehicle-request.service';
import { NotificationsService } from '../notifications/notifications.service';
import { OnEvent } from '@nestjs/event-emitter';
import { HistoryUpdatedEvent, LocationUpdatedEvent, NotificationUpdatedEvent, RequestUpdatedEvent, UserUpdatedEvent } from '../events/events';

@WebSocketGateway({
  cors: {
    origin: '*',
  },
})
export class TrackingGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  constructor(
    private jwtService: JwtService,
    private configService: ConfigService,
    private tripsService: TripsService,
    private vehiclesService: VehiclesService,
    private usersService: UsersService,
    private vehicleRequestService: VehicleRequestService,
    private notificationsService: NotificationsService,
  ) {}

  async handleConnection(client: Socket) {
    try {
      const token = client.handshake.auth.token || client.handshake.headers.authorization?.split(' ')[1];
      if (!token) {
        client.disconnect();
        return;
      }

      const payload = this.jwtService.verify(token, {
        secret: this.configService.get<string>('JWT_SECRET') || 'your-secret-key-change-in-production',
      });

      client.data.userId = payload.sub;
      client.data.userRole = payload.role;

      console.log(`Client connected: ${client.id}, User: ${payload.sub}`);
    } catch (error) {
      console.error('WebSocket authentication failed:', error);
      client.disconnect();
    }
  }

  handleDisconnect(client: Socket) {
    console.log(`Client disconnected: ${client.id}`);
  }

  @SubscribeMessage('subscribe:trips')
  async handleSubscribeTrips(@ConnectedSocket() client: Socket) {
    // Send initial active trips data
    const activeTrips = await this.tripsService.findActive();
    client.emit('trips:update', activeTrips);

    // Join trips room for updates
    client.join('trips');
  }

  @SubscribeMessage('subscribe:vehicles')
  async handleSubscribeVehicles(@ConnectedSocket() client: Socket) {
    const activeTrips = await this.tripsService.findActive();
    const vehicleLocations: any[] = [];

    for (const trip of activeTrips) {
      const vehicle = await this.vehiclesService.findById(trip.vehicleId.toString());
      if (vehicle && trip.route.length > 0) {
        const lastLocation = trip.route[trip.route.length - 1];
        vehicleLocations.push({
          vehicleId: (vehicle as any)._id.toString(),
          plateNumber: vehicle.plateNumber,
          location: {
            lat: lastLocation.lat,
            lng: lastLocation.lng,
          },
          tripId: (trip as any)._id.toString(),
        });
      }
    }

    client.emit('vehicles:update', vehicleLocations);
    client.join('vehicles');
  }

  @SubscribeMessage('subscribe:drivers')
  async handleSubscribeDrivers(@ConnectedSocket() client: Socket) {
    const activeTrips = await this.tripsService.findActive();
    const driverLocations: any[] = [];

    for (const trip of activeTrips) {
      const driver = await this.usersService.findById(trip.driverId.toString());
      if (driver && trip.route.length > 0) {
        const lastLocation = trip.route[trip.route.length - 1];
        driverLocations.push({
          driverId: (driver as any)._id.toString(),
          driverName: driver.name,
          location: {
            lat: lastLocation.lat,
            lng: lastLocation.lng,
          },
          tripId: (trip as any)._id.toString(),
        });
      }
    }

    client.emit('drivers:update', driverLocations);
    client.join('drivers');
  }

  // Method to broadcast trip updates
  broadcastTripUpdate(trip: any) {
    this.server.to('trips').emit('trips:update', [trip]);
    this.broadcastVehicleUpdate();
    this.broadcastDriverUpdate();
  }

  // Method to broadcast vehicle location updates
  async broadcastVehicleUpdate() {
    const activeTrips = await this.tripsService.findActive();
    const vehicleLocations: any[] = [];

    for (const trip of activeTrips) {
      const vehicle = await this.vehiclesService.findById(trip.vehicleId.toString());
      if (vehicle && trip.route.length > 0) {
        const lastLocation = trip.route[trip.route.length - 1];
        vehicleLocations.push({
          vehicleId: (vehicle as any)._id.toString(),
          plateNumber: vehicle.plateNumber,
          location: {
            lat: lastLocation.lat,
            lng: lastLocation.lng,
          },
          tripId: (trip as any)._id.toString(),
        });
      }
    }

    this.server.to('vehicles').emit('vehicles:update', vehicleLocations);
  }

  // Method to broadcast driver location updates
  async broadcastDriverUpdate() {
    const activeTrips = await this.tripsService.findActive();
    const driverLocations: any[] = [];

    for (const trip of activeTrips) {
      const driver = await this.usersService.findById(trip.driverId.toString());
      if (driver && trip.route.length > 0) {
        const lastLocation = trip.route[trip.route.length - 1];
        driverLocations.push({
          driverId: (driver as any)._id.toString(),
          driverName: driver.name,
          location: {
            lat: lastLocation.lat,
            lng: lastLocation.lng,
          },
          tripId: (trip as any)._id.toString(),
        });
      }
    }

    this.server.to('drivers').emit('drivers:update', driverLocations);
  }

  @SubscribeMessage('subscribe:requests')
  async handleSubscribeRequests(@ConnectedSocket() client: Socket) {
    try {
      // Get user from client data
      const userId = client.data.userId;
      if (!userId) {
        return;
      }

      // Get user to determine role-based requests
      const user = await this.usersService.findById(userId);
      if (!user) {
        return;
      }

      // Get requests based on user role
      const requests = await this.vehicleRequestService.findAll(user);
      client.emit('requests:updated', requests);

      // Join requests room for updates
      client.join('requests');
    } catch (error) {
      console.error('Error subscribing to requests:', error);
    }
  }

  @SubscribeMessage('subscribe:users')
  async handleSubscribeUsers(@ConnectedSocket() client: Socket) {
    try {
      // Get all users (for supervisors list, etc.)
      const users = await this.usersService.findAll();
      client.emit('users:updated', users);

      // Join users room for updates
      client.join('users');
    } catch (error) {
      console.error('Error subscribing to users:', error);
    }
  }

  @SubscribeMessage('subscribe:notifications')
  async handleSubscribeNotifications(@ConnectedSocket() client: Socket) {
    try {
      const userId = client.data.userId;
      if (!userId) {
        return;
      }

      // Join notifications room for this user
      client.join(`notifications:${userId}`);
    } catch (error) {
      console.error('Error subscribing to notifications:', error);
    }
  }

  @SubscribeMessage('subscribe:history')
  async handleSubscribeHistory(@ConnectedSocket() client: Socket) {
    try {
      const userId = client.data.userId;
      if (!userId) {
        return;
      }

      client.join(`history:${userId}`);
    } catch (error) {
      console.error('Error subscribing to history:', error);
    }
  }

  // Method to broadcast request updates
  async broadcastRequestUpdate() {
    try {
      // Get all connected clients in requests room
      const clients = await this.server.in('requests').fetchSockets();
      
      for (const clientSocket of clients) {
        try {
          const userId = clientSocket.data.userId;
          if (!userId) continue;

          const user = await this.usersService.findById(userId);
          if (!user) continue;

          const requests = await this.vehicleRequestService.findAll(user);
          clientSocket.emit('requests:updated', requests);
        } catch (error) {
          console.error('Error broadcasting request update to client:', error);
        }
      }
    } catch (error) {
      console.error('Error broadcasting request updates:', error);
    }
  }

  // Method to broadcast user updates
  async broadcastUserUpdate() {
    try {
      const users = await this.usersService.findAll();
      this.server.to('users').emit('users:updated', users);
    } catch (error) {
      console.error('Error broadcasting user updates:', error);
    }
  }

  // Method to broadcast notification to specific user
  async broadcastNotification(userId: string, payload: any) {
    this.server.to(`notifications:${userId}`).emit('notifications:new', payload);
  }

  private async broadcastHistoryToParticipants(requestId: string) {
    try {
      const request = await this.vehicleRequestService.findById(requestId);
      if (!request) {
        return;
      }

      const participantIds = new Set<string>();
      const addId = (id?: any) => {
        if (!id) return;
        const value = typeof id === 'object' && id !== null ? id._id || id.id : id;
        if (!value) return;
        participantIds.add(value.toString());
      };

      addId(request.requesterId);
      addId(request.supervisorId);
      if (Array.isArray(request.approvalChain)) {
        for (const entry of request.approvalChain as any[]) {
          addId(entry?.approverId);
        }
      }
      if (Array.isArray(request.actionHistory)) {
        for (const action of request.actionHistory as any[]) {
          addId(action?.performedBy);
        }
      }

      for (const participantId of participantIds) {
        this.server.to(`history:${participantId}`).emit('history:updated', {
          requestId,
        });
      }
    } catch (error) {
      console.error('Error broadcasting history update:', error);
    }
  }

  // Event listeners
  @OnEvent('request.updated')
  async handleRequestUpdated(event: RequestUpdatedEvent) {
    await this.broadcastRequestUpdate();
  }

  @OnEvent('user.updated')
  async handleUserUpdated(event: UserUpdatedEvent) {
    await this.broadcastUserUpdate();
  }

  @OnEvent('notification.created')
  async handleNotificationCreated(event: NotificationUpdatedEvent) {
    const unread =
      event.unread !== undefined
        ? event.unread
        : await this.notificationsService.getUnreadCount(event.userId);
    await this.broadcastNotification(event.userId, {
      type: 'created',
      notification: event.notification,
      unread,
    });
  }

  @OnEvent('notification.updated')
  async handleNotificationUpdated(event: NotificationUpdatedEvent) {
    const unread =
      event.unread !== undefined
        ? event.unread
        : await this.notificationsService.getUnreadCount(event.userId);
    await this.broadcastNotification(event.userId, {
      type: 'updated',
      notification: event.notification,
      unread,
    });
  }

  @OnEvent('history.updated')
  async handleHistoryUpdated(event: HistoryUpdatedEvent) {
    await this.broadcastHistoryToParticipants(event.requestId);
  }

  @OnEvent('location.updated')
  async handleLocationUpdated(event: LocationUpdatedEvent) {
    // Broadcast location update to trip-specific room
    this.server.to(`trip:${event.tripId}`).emit('trip:location', {
      tripId: event.tripId,
      driverId: event.driverId,
      location: event.location,
    });
    
    // Also update vehicle/driver locations for general tracking
    this.broadcastVehicleUpdate();
    this.broadcastDriverUpdate();
  }
}

