import { Module } from '@nestjs/common';
import { WorkflowService } from './workflow.service';
import { WorkflowTransitionService } from './workflow-transition.service';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [UsersModule],
  providers: [WorkflowService, WorkflowTransitionService],
  exports: [WorkflowService, WorkflowTransitionService],
})
export class WorkflowModule {}

