import { Controller, Get, Put, Post, Delete, Param, Body, UseGuards, Request } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { FcmService } from './fcm.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RegisterDeviceTokenDto } from './dto/register-device-token.dto';

@Controller('notifications')
@UseGuards(JwtAuthGuard)
export class NotificationsController {
  constructor(
    private notificationsService: NotificationsService,
    private fcmService: FcmService,
  ) {}

  @Get()
  async getUserNotifications(@Request() req) {
    return this.notificationsService.getUserNotifications(req.user._id.toString());
  }

  @Get('unread-count')
  async getUnreadCount(@Request() req) {
    const unread = await this.notificationsService.getUnreadCount(req.user._id.toString());
    return { unread };
  }

  @Put(':id/read')
  async markAsRead(@Param('id') id: string, @Request() req) {
    await this.notificationsService.markAsRead(id, req.user._id.toString());
    const unread = await this.notificationsService.getUnreadCount(req.user._id.toString());
    return { message: 'Notification marked as read', unread };
  }

  @Put('read-all')
  async markAllAsRead(@Request() req) {
    await this.notificationsService.markAllAsRead(req.user._id.toString());
    return { message: 'All notifications marked as read', unread: 0 };
  }

  @Post('register-token')
  async registerDeviceToken(@Body() registerDto: RegisterDeviceTokenDto, @Request() req) {
    const userId = req.user._id.toString();
    const deviceToken = await this.fcmService.registerDeviceToken(
      userId,
      registerDto.token,
      registerDto.platform,
      registerDto.deviceName,
    );
    return {
      message: 'Device token registered successfully',
      deviceToken: {
        id: deviceToken._id,
        platform: deviceToken.platform,
        deviceName: deviceToken.deviceName,
      },
    };
  }

  @Delete('unregister-token')
  async unregisterDeviceToken(@Body('token') token: string, @Request() req) {
    await this.fcmService.unregisterDeviceToken(token);
    return { message: 'Device token unregistered successfully' };
  }

  @Get('device-tokens')
  async getUserDeviceTokens(@Request() req) {
    const userId = req.user._id.toString();
    const deviceTokens = await this.fcmService.getUserDeviceTokens(userId);
    return deviceTokens.map((dt) => ({
      id: dt._id,
      platform: dt.platform,
      deviceName: dt.deviceName,
      lastUsedAt: dt.lastUsedAt,
    }));
  }
}

