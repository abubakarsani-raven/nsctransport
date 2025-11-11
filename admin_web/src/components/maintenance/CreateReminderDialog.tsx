"use client";

import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { Bell } from "lucide-react";
import { useToast } from "@/components/ui/use-toast";
import { MaintenanceType, MAINTENANCE_TYPE_LABELS, CreateReminderDto } from "@/types/maintenance";
import { DatePicker } from "@/components/ui/date-picker";

interface CreateReminderDialogProps {
  vehicleId: string;
}

export function CreateReminderDialog({ vehicleId }: CreateReminderDialogProps) {
  const [open, setOpen] = useState(false);
  const qc = useQueryClient();
  const { success, error } = useToast();
  const [form, setForm] = useState<CreateReminderDto>({
    maintenanceType: MaintenanceType.OIL_CHANGE,
    customTypeName: "",
    reminderIntervalDays: 90,
    lastPerformedDate: undefined,
    isActive: true,
    notes: "",
  });

  const createMutation = useMutation({
    mutationFn: async (data: CreateReminderDto) => {
      const res = await fetch(`/api/maintenance/vehicles/${vehicleId}/reminders`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      });
      if (!res.ok) {
        const errorData = await res.json().catch(() => ({}));
        throw new Error(errorData.message || "Failed to create reminder");
      }
      return res.json();
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["maintenance-reminders", vehicleId] });
      setOpen(false);
      setForm({
        maintenanceType: MaintenanceType.OIL_CHANGE,
        customTypeName: "",
        reminderIntervalDays: 90,
        lastPerformedDate: undefined,
        isActive: true,
        notes: "",
      });
      success("Reminder created successfully");
    },
    onError: (err: any) => {
      error(err.message || "Failed to create reminder");
    },
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const submitData = {
      ...form,
      reminderIntervalDays: Number(form.reminderIntervalDays),
      lastPerformedDate: form.lastPerformedDate ? form.lastPerformedDate.toISOString() : undefined,
      customTypeName: form.maintenanceType === MaintenanceType.OTHER ? form.customTypeName : undefined,
    };
    createMutation.mutate(submitData as any);
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button>
          <Bell className="h-4 w-4 mr-2" />
          Set Reminder
        </Button>
      </DialogTrigger>
      <DialogContent className="max-w-lg">
        <DialogHeader>
          <DialogTitle>Set Maintenance Reminder</DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="maintenanceType">Maintenance Type *</Label>
            <Select
              value={form.maintenanceType}
              onValueChange={(value) => setForm({ ...form, maintenanceType: value as MaintenanceType })}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {Object.entries(MAINTENANCE_TYPE_LABELS).map(([value, label]) => (
                  <SelectItem key={value} value={value}>
                    {label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          {form.maintenanceType === MaintenanceType.OTHER && (
            <div className="space-y-2">
              <Label htmlFor="customTypeName">Custom Type Name *</Label>
              <Input
                id="customTypeName"
                value={form.customTypeName || ""}
                onChange={(e) => setForm({ ...form, customTypeName: e.target.value })}
                placeholder="Enter custom type"
                required={form.maintenanceType === MaintenanceType.OTHER}
              />
            </div>
          )}

          <div className="space-y-2">
            <Label htmlFor="reminderIntervalDays">Reminder Interval (days) *</Label>
            <Input
              id="reminderIntervalDays"
              type="number"
              min="1"
              value={form.reminderIntervalDays}
              onChange={(e) => setForm({ ...form, reminderIntervalDays: Number(e.target.value) })}
              required
              placeholder="e.g., 90"
            />
            <p className="text-xs text-muted-foreground">
              How often should this reminder be triggered? (e.g., 90 for every 3 months)
            </p>
          </div>

          <div className="space-y-2">
            <Label>Last Performed Date (optional)</Label>
            <DatePicker
              date={form.lastPerformedDate}
              onDateChange={(date) => setForm({ ...form, lastPerformedDate: date })}
              placeholder="Select date (optional)"
            />
            <p className="text-xs text-muted-foreground">
              If provided, the next reminder will be calculated from this date
            </p>
          </div>

          <div className="space-y-2">
            <Label htmlFor="notes">Notes</Label>
            <Textarea
              id="notes"
              value={form.notes || ""}
              onChange={(e) => setForm({ ...form, notes: e.target.value })}
              placeholder="Additional notes about this reminder"
              rows={3}
            />
          </div>

          <div className="flex justify-end gap-2">
            <Button type="button" variant="outline" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button type="submit" disabled={createMutation.isPending}>
              {createMutation.isPending ? "Creating..." : "Create Reminder"}
            </Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
}

