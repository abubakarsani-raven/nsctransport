import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Notification, NotificationDocument, NotificationType } from './schemas/notification.schema';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { NotificationUpdatedEvent } from '../events/events';
import { FcmService } from './fcm.service';

@Injectable()
export class NotificationsService {
  constructor(
    @InjectModel(Notification.name) private notificationModel: Model<NotificationDocument>,
    private eventEmitter: EventEmitter2,
    private fcmService: FcmService,
  ) {}

  async create(notificationData: {
    userId: string;
    type: NotificationType;
    title: string;
    message: string;
    relatedRequestId?: string;
  }): Promise<NotificationDocument> {
    const notification = new this.notificationModel(notificationData);
    const saved = await notification.save();
    const plain = typeof saved.toObject === 'function' ? saved.toObject() : saved;
    this.eventEmitter.emit(
      'notification.created',
      new NotificationUpdatedEvent(notificationData.userId, plain, undefined),
    );

    // Send push notification via FCM
    this.fcmService
      .sendNotificationToUser(notificationData.userId, notificationData.title, notificationData.message, {
        type: notificationData.type,
        requestId: notificationData.relatedRequestId || '',
        notificationId: (saved._id as any).toString(),
      })
      .catch((error) => {
        // Log error but don't fail the notification creation
        console.error('Failed to send FCM notification:', error);
      });

    return saved;
  }

  async sendNotification(
    userId: string,
    type: NotificationType,
    title: string,
    message: string,
    relatedRequestId?: string,
  ): Promise<void> {
    await this.create({
      userId,
      type,
      title,
      message,
      relatedRequestId,
    });
  }

  async sendNotificationToMultipleUsers(
    userIds: string[],
    type: NotificationType,
    title: string,
    message: string,
    relatedRequestId?: string,
  ): Promise<void> {
    if (!userIds || userIds.length === 0) {
      return;
    }

    // Remove duplicates and filter out empty strings
    const uniqueUserIds = [...new Set(userIds)].filter(id => id && id.trim() !== '');
    
    if (uniqueUserIds.length === 0) {
      return;
    }

    // Create notifications for all users
    // Note: Each create() call will send FCM notification individually
    // For better performance, we could batch FCM calls, but for now this ensures
    // each user gets both in-app and push notifications
    const notificationPromises = uniqueUserIds.map(userId =>
      this.create({
        userId,
        type,
        title,
        message,
        relatedRequestId,
      }),
    );

    await Promise.all(notificationPromises);
  }

  async getUserNotifications(userId: string): Promise<NotificationDocument[]> {
    return this.notificationModel.find({ userId }).sort({ createdAt: -1 }).exec();
  }

  async markAsRead(notificationId: string, userId: string): Promise<void> {
    await this.notificationModel
      .updateOne(
        { _id: notificationId, userId },
        { read: true },
      )
      .exec();

    const updated = await this.notificationModel
      .findOne({ _id: notificationId, userId })
      .lean();
    const unread = await this.getUnreadCount(userId);
    this.eventEmitter.emit(
     'notification.updated',
      new NotificationUpdatedEvent(userId, updated, unread),
    );
  }

  async markAllAsRead(userId: string): Promise<void> {
    await this.notificationModel
      .updateMany(
        { userId, read: false },
        { read: true },
      )
      .exec();

    this.eventEmitter.emit(
      'notification.updated',
      new NotificationUpdatedEvent(userId, null, 0),
    );
  }

  async getUnreadCount(userId: string): Promise<number> {
    return this.notificationModel.countDocuments({ userId, read: false }).exec();
  }
}

