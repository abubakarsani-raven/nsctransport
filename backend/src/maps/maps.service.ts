import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Client, UnitSystem } from '@googlemaps/google-maps-services-js';
import mapsConfig from '../config/maps.config';

@Injectable()
export class MapsService {
  private client: Client;
  private apiKey: string;

  constructor(private configService: ConfigService) {
    this.client = new Client({});
    this.apiKey = this.configService.get<string>('GOOGLE_MAPS_API_KEY') || '';
  }

  async calculateDistance(
    origin: { lat: number; lng: number },
    destination: { lat: number; lng: number },
  ): Promise<{ distance: number; duration: number }> {
    try {
      const response = await this.client.distancematrix({
        params: {
          origins: [`${origin.lat},${origin.lng}`],
          destinations: [`${destination.lat},${destination.lng}`],
          key: this.apiKey,
          units: UnitSystem.metric,
        },
      });

      const element = response.data.rows[0]?.elements[0];
      if (element?.status === 'OK') {
        return {
          distance: element.distance.value / 1000, // Convert to kilometers
          duration: element.duration.value / 60, // Convert to minutes
        };
      }
      throw new Error('Unable to calculate distance');
    } catch (error) {
      throw new Error(`Distance calculation failed: ${error.message}`);
    }
  }

  async getRoute(
    origin: { lat: number; lng: number },
    destination: { lat: number; lng: number },
  ): Promise<any> {
    try {
      const response = await this.client.directions({
        params: {
          origin: `${origin.lat},${origin.lng}`,
          destination: `${destination.lat},${destination.lng}`,
          key: this.apiKey,
        },
      });

      return response.data;
    } catch (error) {
      throw new Error(`Route calculation failed: ${error.message}`);
    }
  }

  async geocodeAddress(address: string): Promise<{ lat: number; lng: number }> {
    try {
      const response = await this.client.geocode({
        params: {
          address,
          key: this.apiKey,
        },
      });

      const location = response.data.results[0]?.geometry?.location;
      if (location) {
        return { lat: location.lat, lng: location.lng };
      }
      throw new Error('Unable to geocode address');
    } catch (error) {
      throw new Error(`Geocoding failed: ${error.message}`);
    }
  }

  async reverseGeocode(lat: number, lng: number): Promise<string> {
    try {
      const response = await this.client.reverseGeocode({
        params: {
          latlng: { lat, lng },
          key: this.apiKey,
        },
      });

      return response.data.results[0]?.formatted_address || '';
    } catch (error) {
      throw new Error(`Reverse geocoding failed: ${error.message}`);
    }
  }
}

