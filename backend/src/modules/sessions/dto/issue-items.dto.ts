import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsInt,
  IsNotEmpty,
  IsPositive,
  IsString,
  ValidateNested,
} from 'class-validator';

export class CreateIssueItemDto {
  @IsString()
  @IsNotEmpty()
  plantId!: string;

  @Type(() => Number)
  @IsInt()
  @IsPositive()
  quantity!: number;
}

export class IssueItemsDto {
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => CreateIssueItemDto)
  items!: CreateIssueItemDto[];
}
