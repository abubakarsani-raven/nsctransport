import {
  registerDecorator,
  ValidationOptions,
  ValidationArguments,
} from 'class-validator';

export function IsDateAfterOrEqual(
  property: string,
  validationOptions?: ValidationOptions,
) {
  return function (object: Object, propertyName: string) {
    registerDecorator({
      name: 'isDateAfterOrEqual',
      target: object.constructor,
      propertyName: propertyName,
      constraints: [property],
      options: validationOptions,
      validator: {
        validate(value: any, args: ValidationArguments) {
          const [relatedPropertyName] = args.constraints;
          const relatedValue = (args.object as any)[relatedPropertyName];
          
          if (!value || !relatedValue) {
            return true; // Skip validation if either date is not provided
          }
          
          const date = new Date(value);
          const relatedDate = new Date(relatedValue);
          
          // Set time to midnight for accurate date comparison
          date.setHours(0, 0, 0, 0);
          relatedDate.setHours(0, 0, 0, 0);
          
          return date >= relatedDate;
        },
        defaultMessage(args: ValidationArguments) {
          const [relatedPropertyName] = args.constraints;
          return `${args.property} must be greater than or equal to ${relatedPropertyName}`;
        },
      },
    });
  };
}












