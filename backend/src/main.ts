import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';
const morgan = require('morgan');

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  
  // HTTP request logger
  app.use(morgan('dev'));
  
  // Enable CORS
  const allowedOrigins = process.env.NODE_ENV === 'production' 
    ? [
        process.env.ADMIN_WEB_URL,
        process.env.VERCEL_URL ? `https://${process.env.VERCEL_URL}` : null,
        // Add other allowed origins if needed
      ].filter(Boolean)
    : true;
    
  app.enableCors({
    origin: allowedOrigins,
    credentials: true,
  });
  
  // Global validation pipe
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );
  
  await app.listen(process.env.PORT ?? 3000);
}
bootstrap();
