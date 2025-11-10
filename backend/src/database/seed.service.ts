import { Injectable, OnModuleInit } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import * as bcrypt from 'bcrypt';
import { User, UserDocument, UserRole } from '../users/schemas/user.schema';

@Injectable()
export class SeedService implements OnModuleInit {
  constructor(@InjectModel(User.name) private userModel: Model<UserDocument>) {}

  async onModuleInit() {
    await this.seedAdmin();
  }

  async seedAdmin() {
    const adminEmail = 'admin@transport.com';
    const existingAdmin = await this.userModel.findOne({ email: adminEmail }).exec();

    if (!existingAdmin) {
      const hashedPassword = await bcrypt.hash('admin123', 10);
      const admin = new this.userModel({
        email: adminEmail,
        password: hashedPassword,
        name: 'System Administrator',
        phone: '+1234567890',
        role: UserRole.ADMIN,
        employeeId: 'ADMIN001',
      });

      await admin.save();
      console.log('✅ Admin user created successfully!');
      console.log('📧 Email: admin@transport.com');
      console.log('🔑 Password: admin123');
    } else {
      console.log('ℹ️  Admin user already exists');
    }
  }
}

