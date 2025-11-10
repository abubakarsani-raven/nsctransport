import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { NotificationDeviceToken, NotificationDeviceTokenDocument } from './schemas/device-token.schema';
import * as path from 'path';
import * as fs from 'fs';

@Injectable()
export class FcmService implements OnModuleInit {
  private readonly logger = new Logger(FcmService.name);
  private firebaseApp: admin.app.App | null = null;

  constructor(
    private configService: ConfigService,
    @InjectModel(NotificationDeviceToken.name)
    private deviceTokenModel: Model<NotificationDeviceTokenDocument>,
  ) {}

  async onModuleInit() {
    await this.initializeFirebase();
  }

  private async initializeFirebase() {
    try {
      const serviceAccountPath = this.configService.get<string>('FIREBASE_SERVICE_ACCOUNT_PATH');
      const firebaseCredentials = this.configService.get<string>('FIREBASE_CREDENTIALS');

      if (serviceAccountPath) {
        // Resolve path relative to project root (process.cwd())
        const absolutePath = path.resolve(process.cwd(), serviceAccountPath);
        
        // Check if file exists
        if (!fs.existsSync(absolutePath)) {
          this.logger.error(`Firebase service account file not found at: ${absolutePath}`);
          this.logger.warn('Push notifications will be disabled');
          return;
        }

        // Read and parse the service account file
        const serviceAccountJson = fs.readFileSync(absolutePath, 'utf8');
        const serviceAccount = JSON.parse(serviceAccountJson);
        
        this.firebaseApp = admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
        });
        this.logger.log(`Firebase Admin initialized with service account file: ${absolutePath}`);
      } else if (firebaseCredentials) {
        // Initialize with credentials JSON string
        const serviceAccount = JSON.parse(firebaseCredentials);
        this.firebaseApp = admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
        });
        this.logger.log('Firebase Admin initialized with credentials from environment');
      } else {
        this.logger.warn('Firebase credentials not found. Push notifications will be disabled.');
        this.logger.warn('Set FIREBASE_SERVICE_ACCOUNT_PATH or FIREBASE_CREDENTIALS environment variable');
      }
    } catch (error) {
      this.logger.error('Failed to initialize Firebase Admin:', error);
      this.logger.warn('Push notifications will be disabled');
    }
  }

  async sendNotificationToDevice(
    token: string,
    title: string,
    body: string,
    data?: Record<string, string>,
  ): Promise<boolean> {
    if (!this.firebaseApp) {
      this.logger.warn('Firebase not initialized. Cannot send push notification.');
      return false;
    }

    try {
      const message: admin.messaging.Message = {
        token,
        notification: {
          title,
          body,
        },
        data: data || {},
        android: {
          priority: 'high' as const,
          notification: {
            sound: 'default',
            channelId: 'default',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      };

      const response = await admin.messaging().send(message);
      this.logger.log(`Successfully sent message: ${response}`);
      return true;
    } catch (error: any) {
      this.logger.error('Error sending push notification:', error);

      // If token is invalid, remove it from database
      if (error.code === 'messaging/invalid-registration-token' || 
          error.code === 'messaging/registration-token-not-registered') {
        await this.deviceTokenModel.deleteOne({ token }).exec();
        this.logger.warn(`Removed invalid token: ${token}`);
      }

      return false;
    }
  }

  async sendNotificationToUser(
    userId: string,
    title: string,
    body: string,
    data?: Record<string, string>,
  ): Promise<number> {
    if (!this.firebaseApp) {
      this.logger.warn('Firebase not initialized. Cannot send push notification.');
      return 0;
    }

    // Get all device tokens for the user
    const deviceTokens = await this.deviceTokenModel.find({ userId }).exec();
    
    if (deviceTokens.length === 0) {
      this.logger.debug(`No device tokens found for user: ${userId}`);
      return 0;
    }

    let successCount = 0;
    const tokens = deviceTokens.map(dt => dt.token);

    // Send to all devices (Firebase supports up to 500 tokens per multicast)
    const batchSize = 500;
    for (let i = 0; i < tokens.length; i += batchSize) {
      const batch = tokens.slice(i, i + batchSize);
      const results = await this.sendNotificationToMultipleDevices(batch, title, body, data);
      successCount += results;
    }

    // Update lastUsedAt for successful tokens
    if (successCount > 0) {
      await this.deviceTokenModel.updateMany(
        { userId, token: { $in: tokens } },
        { lastUsedAt: new Date() },
      ).exec();
    }

    return successCount;
  }

  async sendNotificationToMultipleUsers(
    userIds: string[],
    title: string,
    body: string,
    data?: Record<string, string>,
  ): Promise<number> {
    if (!this.firebaseApp || userIds.length === 0) {
      return 0;
    }

    // Get all device tokens for all users
    const deviceTokens = await this.deviceTokenModel
      .find({ userId: { $in: userIds } })
      .exec();

    if (deviceTokens.length === 0) {
      this.logger.debug(`No device tokens found for users: ${userIds.join(', ')}`);
      return 0;
    }

    const tokens = deviceTokens.map(dt => dt.token);
    let successCount = 0;

    // Send to all devices in batches
    const batchSize = 500;
    for (let i = 0; i < tokens.length; i += batchSize) {
      const batch = tokens.slice(i, i + batchSize);
      const results = await this.sendNotificationToMultipleDevices(batch, title, body, data);
      successCount += results;
    }

    // Update lastUsedAt for successful tokens
    if (successCount > 0) {
      await this.deviceTokenModel.updateMany(
        { userId: { $in: userIds }, token: { $in: tokens } },
        { lastUsedAt: new Date() },
      ).exec();
    }

    return successCount;
  }

  private async sendNotificationToMultipleDevices(
    tokens: string[],
    title: string,
    body: string,
    data?: Record<string, string>,
  ): Promise<number> {
    if (!this.firebaseApp || tokens.length === 0) {
      return 0;
    }

    try {
      const message: admin.messaging.MulticastMessage = {
        tokens,
        notification: {
          title,
          body,
        },
        data: data || {},
        android: {
          priority: 'high' as const,
          notification: {
            sound: 'default',
            channelId: 'default',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      this.logger.log(`Successfully sent ${response.successCount} messages, failed ${response.failureCount}`);

      // Remove invalid tokens
      if (response.failureCount > 0) {
        const invalidTokens: string[] = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            const error = resp.error;
            if (error?.code === 'messaging/invalid-registration-token' ||
                error?.code === 'messaging/registration-token-not-registered') {
              invalidTokens.push(tokens[idx]);
            }
          }
        });

        if (invalidTokens.length > 0) {
          await this.deviceTokenModel.deleteMany({ token: { $in: invalidTokens } }).exec();
          this.logger.warn(`Removed ${invalidTokens.length} invalid tokens`);
        }
      }

      return response.successCount;
    } catch (error) {
      this.logger.error('Error sending multicast push notification:', error);
      return 0;
    }
  }

  async registerDeviceToken(
    userId: string,
    token: string,
    platform: string,
    deviceName?: string,
  ): Promise<NotificationDeviceTokenDocument> {
    // Check if token already exists
    const existingToken = await this.deviceTokenModel.findOne({ token }).exec();

    if (existingToken) {
      // Update existing token
      if (existingToken.userId !== userId) {
        // Token belongs to different user, update it
        existingToken.userId = userId;
      }
      existingToken.platform = platform;
      if (deviceName) {
        existingToken.deviceName = deviceName;
      }
      existingToken.lastUsedAt = new Date();
      return existingToken.save();
    } else {
      // Create new token
      const deviceToken = new this.deviceTokenModel({
        userId,
        token,
        platform,
        deviceName,
        lastUsedAt: new Date(),
      });
      return deviceToken.save();
    }
  }

  async unregisterDeviceToken(token: string): Promise<void> {
    await this.deviceTokenModel.deleteOne({ token }).exec();
  }

  async unregisterAllUserTokens(userId: string): Promise<void> {
    await this.deviceTokenModel.deleteMany({ userId }).exec();
  }

  async getUserDeviceTokens(userId: string): Promise<NotificationDeviceTokenDocument[]> {
    return this.deviceTokenModel.find({ userId }).exec();
  }
}

