"use client";

import { useQuery, useQueryClient, useMutation } from "@tanstack/react-query";
import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Pencil, Trash2, Bell } from "lucide-react";
import { useToast } from "@/components/ui/use-toast";
import { MaintenanceReminder, MAINTENANCE_TYPE_LABELS } from "@/types/maintenance";
import { CreateReminderDialog } from "./CreateReminderDialog";
import { EditReminderDialog } from "./EditReminderDialog";

async function fetchJSON<T>(url: string): Promise<T> {
  const res = await fetch(url, { cache: "no-store" });
  if (!res.ok) throw new Error("Failed");
  return res.json();
}

interface MaintenanceRemindersListProps {
  vehicleId: string;
}

export function MaintenanceRemindersList({ vehicleId }: MaintenanceRemindersListProps) {
  const qc = useQueryClient();
  const { success, error } = useToast();
  const [editingReminder, setEditingReminder] = useState<MaintenanceReminder | null>(null);

  const { data: reminders = [], isLoading } = useQuery<MaintenanceReminder[]>({
    queryKey: ["maintenance-reminders", vehicleId],
    queryFn: () => fetchJSON<MaintenanceReminder[]>(`/api/maintenance/vehicles/${vehicleId}/reminders`),
  });

  const deleteMutation = useMutation({
    mutationFn: async (id: string) => {
      const res = await fetch(`/api/maintenance/reminders/${id}`, {
        method: "DELETE",
      });
      if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        throw new Error(data.message || "Failed to delete reminder");
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["maintenance-reminders", vehicleId] });
      success("Reminder deleted successfully");
    },
    onError: (err: any) => {
      error(err.message || "Failed to delete reminder");
    },
  });

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString();
  };

  const getTypeLabel = (reminder: MaintenanceReminder) => {
    if (reminder.maintenanceType === "other" && reminder.customTypeName) {
      return reminder.customTypeName;
    }
    return MAINTENANCE_TYPE_LABELS[reminder.maintenanceType] || reminder.maintenanceType;
  };

  const isDueSoon = (nextReminderDate: string) => {
    const daysUntil = Math.ceil(
      (new Date(nextReminderDate).getTime() - new Date().getTime()) / (1000 * 60 * 60 * 24)
    );
    return daysUntil <= 7 && daysUntil >= 0;
  };

  const isOverdue = (nextReminderDate: string) => {
    return new Date(nextReminderDate) < new Date();
  };

  if (isLoading) {
    return <div className="text-center py-4">Loading reminders...</div>;
  }

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <h3 className="text-lg font-semibold">Maintenance Reminders</h3>
        <CreateReminderDialog vehicleId={vehicleId} />
      </div>

      {reminders.length === 0 ? (
        <div className="text-center py-8 text-muted-foreground">
          No reminders set. Create a reminder to get notified about upcoming maintenance.
        </div>
      ) : (
        <div className="grid gap-4">
          {reminders.map((reminder) => {
            const dueSoon = isDueSoon(reminder.nextReminderDate);
            const overdue = isOverdue(reminder.nextReminderDate);

            return (
              <Card key={reminder._id} className={overdue ? "border-destructive" : dueSoon ? "border-orange-500" : ""}>
                <CardHeader className="pb-3">
                  <div className="flex justify-between items-start">
                    <div className="flex items-center gap-2">
                      <Bell className="h-5 w-5" />
                      <CardTitle className="text-base">{getTypeLabel(reminder)}</CardTitle>
                      {!reminder.isActive && <Badge variant="secondary">Inactive</Badge>}
                      {overdue && <Badge variant="destructive">Overdue</Badge>}
                      {dueSoon && !overdue && <Badge variant="outline" className="border-orange-500 text-orange-500">Due Soon</Badge>}
                    </div>
                    <div className="flex gap-2">
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => setEditingReminder(reminder)}
                      >
                        <Pencil className="h-4 w-4" />
                      </Button>
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => {
                          if (confirm("Are you sure you want to delete this reminder?")) {
                            deleteMutation.mutate(reminder._id);
                          }
                        }}
                      >
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </div>
                  </div>
                </CardHeader>
                <CardContent className="space-y-2">
                  <div className="text-sm">
                    <span className="font-medium">Next Reminder:</span>{" "}
                    <span className={overdue ? "text-destructive font-semibold" : dueSoon ? "text-orange-500 font-semibold" : ""}>
                      {formatDate(reminder.nextReminderDate)}
                    </span>
                  </div>
                  <div className="text-sm">
                    <span className="font-medium">Interval:</span> Every {reminder.reminderIntervalDays} days
                  </div>
                  {reminder.lastPerformedDate && (
                    <div className="text-sm">
                      <span className="font-medium">Last Performed:</span> {formatDate(reminder.lastPerformedDate)}
                    </div>
                  )}
                  {reminder.notes && (
                    <div className="text-sm text-muted-foreground">
                      <span className="font-medium">Notes:</span> {reminder.notes}
                    </div>
                  )}
                </CardContent>
              </Card>
            );
          })}
        </div>
      )}

      {editingReminder && (
        <EditReminderDialog
          vehicleId={vehicleId}
          reminder={editingReminder}
          onClose={() => setEditingReminder(null)}
        />
      )}
    </div>
  );
}

