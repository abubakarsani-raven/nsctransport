"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Plus, Pencil, Trash2, UserCheck, X } from "lucide-react";
import { useToast } from "@/components/ui/use-toast";
import { VehicleQuickLinks } from "@/components/transport/VehicleQuickLinks";

type Vehicle = {
  _id: string;
  plateNumber: string;
  make: string;
  model: string;
  year: number;
  capacity: number;
  status: string;
  permanentlyAssignedToUserId?: string | { _id: string; name: string; email: string; roles?: string[] };
  permanentlyAssignedDriverId?: string | { _id: string; name: string; email: string; phone?: string; employeeId?: string };
  permanentAssignmentPosition?: string;
  permanentAssignmentNotes?: string;
};

async function fetchJSON<T>(url: string): Promise<T> {
  const res = await fetch(url, { cache: "no-store" });
  if (!res.ok) throw new Error("Failed");
  return res.json();
}

export default function VehiclesPage() {
  const router = useRouter();
  const qc = useQueryClient();
  const { success, error } = useToast();
  const { data: vehicles = [], isLoading } = useQuery<Vehicle[]>({
    queryKey: ["vehicles"],
    queryFn: () => fetchJSON<Vehicle[]>("/api/vehicles"),
  });

  const [showCreate, setShowCreate] = useState(false);
  const [editingVehicle, setEditingVehicle] = useState<Vehicle | null>(null);
  const [form, setForm] = useState({ plateNumber: "", make: "", model: "", year: "", capacity: "", status: "available" });
  const [showPermanentAssignment, setShowPermanentAssignment] = useState(false);
  const [assigningVehicle, setAssigningVehicle] = useState<Vehicle | null>(null);
  const [permanentForm, setPermanentForm] = useState({ userId: "", driverId: "", position: "", notes: "" });

  const { data: users = [] } = useQuery<any[]>({
    queryKey: ["users"],
    queryFn: () => fetchJSON<any[]>("/api/users"),
  });

  const staffUsers = users.filter(u => {
    const roles = u.roles && u.roles.length > 0 ? u.roles : (u.role ? [u.role] : []);
    return roles.includes('staff');
  });

  const drivers = users.filter(u => {
    const roles = u.roles && u.roles.length > 0 ? u.roles : (u.role ? [u.role] : []);
    return roles.includes('driver');
  });

  async function createVehicle() {
    if (!form.plateNumber || !form.make || !form.model || !form.year || !form.capacity) {
      error("Please fill all required fields");
      return;
    }
    const res = await fetch("/api/vehicles", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        plateNumber: form.plateNumber,
        make: form.make,
        model: form.model,
        year: Number(form.year),
        capacity: Number(form.capacity),
        status: form.status,
      }),
    });
    if (res.ok) {
      setShowCreate(false);
      setForm({ plateNumber: "", make: "", model: "", year: "", capacity: "", status: "available" });
      qc.invalidateQueries({ queryKey: ["vehicles"] });
      success("Vehicle created successfully");
    } else {
      const data = await res.json().catch(() => ({}));
      error(data.message || "Failed to create vehicle");
    }
  }

  async function updateVehicle() {
    if (!editingVehicle || !form.plateNumber || !form.make || !form.model || !form.year || !form.capacity) {
      error("Please fill all required fields");
      return;
    }
    const res = await fetch(`/api/vehicles/${editingVehicle._id}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        plateNumber: form.plateNumber,
        make: form.make,
        model: form.model,
        year: Number(form.year),
        capacity: Number(form.capacity),
        status: form.status,
      }),
    });
    if (res.ok) {
      setEditingVehicle(null);
      setForm({ plateNumber: "", make: "", model: "", year: "", capacity: "", status: "available" });
      qc.invalidateQueries({ queryKey: ["vehicles"] });
      success("Vehicle updated successfully");
    } else {
      const data = await res.json().catch(() => ({}));
      error(data.message || "Failed to update vehicle");
    }
  }

  async function deleteVehicle(id: string) {
    if (!confirm("Are you sure you want to delete this vehicle?")) {
      return;
    }
    const res = await fetch(`/api/vehicles/${id}`, {
      method: "DELETE",
    });
    if (res.ok) {
      qc.invalidateQueries({ queryKey: ["vehicles"] });
      success("Vehicle deleted successfully");
    } else {
      const data = await res.json().catch(() => ({}));
      error(data.message || "Failed to delete vehicle");
    }
  }

  function openEditDialog(vehicle: Vehicle) {
    setEditingVehicle(vehicle);
    setForm({
      plateNumber: vehicle.plateNumber,
      make: vehicle.make,
      model: vehicle.model,
      year: vehicle.year.toString(),
      capacity: vehicle.capacity.toString(),
      status: vehicle.status,
    });
  }

  function closeDialog() {
    setShowCreate(false);
    setEditingVehicle(null);
    setForm({ plateNumber: "", make: "", model: "", year: "", capacity: "", status: "available" });
  }

  async function updateStatus(id: string, status: string) {
    const res = await fetch(`/api/vehicles/${id}/status`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ status }),
    });
    if (res.ok) {
      qc.invalidateQueries({ queryKey: ["vehicles"] });
      success("Vehicle status updated successfully");
    } else {
      const data = await res.json().catch(() => ({}));
      error(data.message || "Failed to update status");
    }
  }

  const getStatusVariant = (status: string) => {
    switch (status) {
      case "available":
        return "default";
      case "assigned":
        return "secondary";
      case "maintenance":
        return "destructive";
      case "permanently_assigned":
        return "outline";
      default:
        return "outline";
    }
  };

  const getStatusLabel = (status: string) => {
    switch (status) {
      case "permanently_assigned":
        return "Official Car";
      case "available":
        return "Available";
      case "assigned":
        return "Assigned";
      case "maintenance":
        return "Maintenance";
      default:
        return status;
    }
  };

  const getAssignedUser = (vehicle: Vehicle) => {
    if (!vehicle.permanentlyAssignedToUserId) return null;
    if (typeof vehicle.permanentlyAssignedToUserId === 'string') return null;
    return vehicle.permanentlyAssignedToUserId;
  };

  const getAssignedDriver = (vehicle: Vehicle) => {
    if (!vehicle.permanentlyAssignedDriverId) return null;
    if (typeof vehicle.permanentlyAssignedDriverId === 'string') return null;
    return vehicle.permanentlyAssignedDriverId;
  };

  function openPermanentAssignmentDialog(vehicle: Vehicle) {
    setAssigningVehicle(vehicle);
    if (vehicle.status === 'permanently_assigned') {
      const assignedUser = getAssignedUser(vehicle);
      const assignedDriver = getAssignedDriver(vehicle);
      setPermanentForm({
        userId: assignedUser?._id || "",
        driverId: assignedDriver?._id || "",
        position: vehicle.permanentAssignmentPosition || "",
        notes: vehicle.permanentAssignmentNotes || "",
      });
    } else {
      setPermanentForm({ userId: "", driverId: "", position: "", notes: "" });
    }
    setShowPermanentAssignment(true);
  }

  function closePermanentAssignmentDialog() {
    setShowPermanentAssignment(false);
    setAssigningVehicle(null);
    setPermanentForm({ userId: "", driverId: "", position: "", notes: "" });
  }

  async function assignPermanently() {
    if (!assigningVehicle || !permanentForm.userId || !permanentForm.driverId || !permanentForm.position) {
      error("Please fill all required fields (Staff, Driver, Position)");
      return;
    }

    const url = assigningVehicle.status === 'permanently_assigned'
      ? `/api/vehicles/${assigningVehicle._id}/permanent-assignment`
      : `/api/vehicles/${assigningVehicle._id}/assign-permanently`;
    
    const method = assigningVehicle.status === 'permanently_assigned' ? 'PUT' : 'POST';

    const res = await fetch(url, {
      method,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        userId: permanentForm.userId,
        driverId: permanentForm.driverId,
        position: permanentForm.position,
        notes: permanentForm.notes || undefined,
      }),
    });

    if (res.ok) {
      closePermanentAssignmentDialog();
      qc.invalidateQueries({ queryKey: ["vehicles"] });
      success(assigningVehicle.status === 'permanently_assigned' ? "Permanent assignment updated successfully" : "Vehicle assigned permanently");
    } else {
      const data = await res.json().catch(() => ({}));
      error(data.message || "Failed to assign vehicle permanently");
    }
  }

  async function removePermanentAssignment(vehicleId: string) {
    if (!confirm("Are you sure you want to remove the permanent assignment? The vehicle will become available.")) {
      return;
    }
    const res = await fetch(`/api/vehicles/${vehicleId}/permanent-assignment`, {
      method: "DELETE",
    });
    if (res.ok) {
      qc.invalidateQueries({ queryKey: ["vehicles"] });
      success("Permanent assignment removed successfully");
    } else {
      const data = await res.json().catch(() => ({}));
      error(data.message || "Failed to remove permanent assignment");
    }
  }

  return (
    <div className="space-y-4">
      <VehicleQuickLinks />
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>Vehicles Management</CardTitle>
            <Dialog open={showCreate} onOpenChange={setShowCreate}>
              <DialogTrigger asChild>
                <Button>
                  <Plus className="mr-2 h-4 w-4" />
                  Create Vehicle
                </Button>
              </DialogTrigger>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle>Create New Vehicle</DialogTitle>
                </DialogHeader>
                <div className="space-y-4 py-4">
                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <Label htmlFor="plateNumber">Plate Number *</Label>
                      <Input
                        id="plateNumber"
                        placeholder="ABC-123"
                        value={form.plateNumber}
                        onChange={(e) => setForm({ ...form, plateNumber: e.target.value })}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="make">Make *</Label>
                      <Input
                        id="make"
                        placeholder="Toyota"
                        value={form.make}
                        onChange={(e) => setForm({ ...form, make: e.target.value })}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="model">Model *</Label>
                      <Input
                        id="model"
                        placeholder="Camry"
                        value={form.model}
                        onChange={(e) => setForm({ ...form, model: e.target.value })}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="year">Year *</Label>
                      <Input
                        id="year"
                        type="number"
                        placeholder="2024"
                        value={form.year}
                        onChange={(e) => setForm({ ...form, year: e.target.value })}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="capacity">Capacity *</Label>
                      <Input
                        id="capacity"
                        type="number"
                        placeholder="5"
                        value={form.capacity}
                        onChange={(e) => setForm({ ...form, capacity: e.target.value })}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="status">Status *</Label>
                      <Select value={form.status} onValueChange={(value) => setForm({ ...form, status: value })}>
                        <SelectTrigger id="status">
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="available">Available</SelectItem>
                          <SelectItem value="assigned">Assigned</SelectItem>
                          <SelectItem value="maintenance">Maintenance</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>
                  </div>
                  <div className="flex gap-2 justify-end">
                    <Button variant="outline" onClick={closeDialog}>
                      Cancel
                    </Button>
                    <Button onClick={createVehicle}>Create</Button>
                  </div>
                </div>
              </DialogContent>
            </Dialog>
          </div>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Plate Number</TableHead>
                <TableHead>Make/Model</TableHead>
                <TableHead>Year</TableHead>
                <TableHead>Capacity</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Permanent Assignment</TableHead>
                <TableHead>Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {isLoading ? (
                <TableRow>
                  <TableCell colSpan={7} className="text-center">
                    Loading...
                  </TableCell>
                </TableRow>
              ) : vehicles.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={7} className="text-center">
                    No vehicles found
                  </TableCell>
                </TableRow>
              ) : (
                vehicles.map((v) => {
                  const assignedUser = getAssignedUser(v);
                  const assignedDriver = getAssignedDriver(v);
                  return (
                    <TableRow key={v._id}>
                      <TableCell className="font-medium">
                        <button
                          onClick={() => router.push(`/transport/vehicles/${v._id}`)}
                          className="text-blue-600 hover:text-blue-800 hover:underline cursor-pointer"
                        >
                          {v.plateNumber}
                        </button>
                      </TableCell>
                      <TableCell>
                        {v.make} {v.model}
                      </TableCell>
                      <TableCell>{v.year}</TableCell>
                      <TableCell>{v.capacity}</TableCell>
                      <TableCell>
                        <Badge variant={getStatusVariant(v.status)}>{getStatusLabel(v.status)}</Badge>
                      </TableCell>
                      <TableCell>
                        {v.status === 'permanently_assigned' && assignedUser ? (
                          <div className="space-y-1">
                            <div className="text-sm">
                              <span className="font-medium">Staff:</span> {assignedUser.name}
                            </div>
                            {v.permanentAssignmentPosition && (
                              <div className="text-xs text-muted-foreground">
                                Position: {v.permanentAssignmentPosition}
                              </div>
                            )}
                            {assignedDriver && (
                              <div className="text-xs text-muted-foreground">
                                Driver: {assignedDriver.name}
                              </div>
                            )}
                          </div>
                        ) : (
                          <span className="text-muted-foreground text-sm">-</span>
                        )}
                      </TableCell>
                      <TableCell>
                        <div className="flex gap-2">
                          {v.status !== 'permanently_assigned' && (
                            <Button
                              variant="outline"
                              size="sm"
                              onClick={() => openPermanentAssignmentDialog(v)}
                              title="Assign Permanently"
                            >
                              <UserCheck className="h-4 w-4" />
                            </Button>
                          )}
                          {v.status === 'permanently_assigned' && (
                            <>
                              <Button
                                variant="outline"
                                size="sm"
                                onClick={() => openPermanentAssignmentDialog(v)}
                                title="Edit Assignment"
                              >
                                <Pencil className="h-4 w-4" />
                              </Button>
                              <Button
                                variant="outline"
                                size="sm"
                                onClick={() => removePermanentAssignment(v._id)}
                                title="Remove Assignment"
                              >
                                <X className="h-4 w-4" />
                              </Button>
                            </>
                          )}
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => openEditDialog(v)}
                          >
                            <Pencil className="h-4 w-4" />
                          </Button>
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => deleteVehicle(v._id)}
                          >
                            <Trash2 className="h-4 w-4" />
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  );
                })
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      {/* Edit Dialog */}
      <Dialog open={!!editingVehicle} onOpenChange={(open) => !open && closeDialog()}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Edit Vehicle</DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="edit-plateNumber">Plate Number *</Label>
                <Input
                  id="edit-plateNumber"
                  placeholder="ABC-123"
                  value={form.plateNumber}
                  onChange={(e) => setForm({ ...form, plateNumber: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="edit-make">Make *</Label>
                <Input
                  id="edit-make"
                  placeholder="Toyota"
                  value={form.make}
                  onChange={(e) => setForm({ ...form, make: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="edit-model">Model *</Label>
                <Input
                  id="edit-model"
                  placeholder="Camry"
                  value={form.model}
                  onChange={(e) => setForm({ ...form, model: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="edit-year">Year *</Label>
                <Input
                  id="edit-year"
                  type="number"
                  placeholder="2024"
                  value={form.year}
                  onChange={(e) => setForm({ ...form, year: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="edit-capacity">Capacity *</Label>
                <Input
                  id="edit-capacity"
                  type="number"
                  placeholder="5"
                  value={form.capacity}
                  onChange={(e) => setForm({ ...form, capacity: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="edit-status">Status *</Label>
                <Select value={form.status} onValueChange={(value) => setForm({ ...form, status: value })}>
                  <SelectTrigger id="edit-status">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="available">Available</SelectItem>
                    <SelectItem value="assigned">Assigned</SelectItem>
                    <SelectItem value="maintenance">Maintenance</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>
            <div className="flex gap-2 justify-end">
              <Button variant="outline" onClick={closeDialog}>
                Cancel
              </Button>
              <Button onClick={updateVehicle}>Update</Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>

      {/* Permanent Assignment Dialog */}
      <Dialog open={showPermanentAssignment} onOpenChange={setShowPermanentAssignment}>
        <DialogContent className="max-w-2xl">
          <DialogHeader>
            <DialogTitle>
              {assigningVehicle?.status === 'permanently_assigned' ? 'Edit Permanent Assignment' : 'Assign Vehicle Permanently'}
            </DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="permanent-staff">Staff Member *</Label>
              <Select
                value={permanentForm.userId}
                onValueChange={(value) => setPermanentForm({ ...permanentForm, userId: value })}
              >
                <SelectTrigger id="permanent-staff">
                  <SelectValue placeholder="Select a staff member" />
                </SelectTrigger>
                <SelectContent>
                  {staffUsers.map((user) => (
                    <SelectItem key={user._id} value={user._id}>
                      {user.name} ({user.email})
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label htmlFor="permanent-driver">Driver *</Label>
              <Select
                value={permanentForm.driverId}
                onValueChange={(value) => setPermanentForm({ ...permanentForm, driverId: value })}
              >
                <SelectTrigger id="permanent-driver">
                  <SelectValue placeholder="Select a driver" />
                </SelectTrigger>
                <SelectContent>
                  {drivers.map((driver) => (
                    <SelectItem key={driver._id} value={driver._id}>
                      {driver.name} {driver.employeeId && `(${driver.employeeId})`}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label htmlFor="permanent-position">Position/Role *</Label>
              <Input
                id="permanent-position"
                placeholder="e.g., DGS, DDGS, Director"
                value={permanentForm.position}
                onChange={(e) => setPermanentForm({ ...permanentForm, position: e.target.value })}
              />
              <p className="text-xs text-muted-foreground">
                The position or role of the staff member (e.g., DGS, DDGS, AD Transport)
              </p>
            </div>
            <div className="space-y-2">
              <Label htmlFor="permanent-notes">Notes (Optional)</Label>
              <Input
                id="permanent-notes"
                placeholder="Additional notes about this assignment"
                value={permanentForm.notes}
                onChange={(e) => setPermanentForm({ ...permanentForm, notes: e.target.value })}
              />
            </div>
            <div className="flex gap-2 justify-end">
              <Button variant="outline" onClick={closePermanentAssignmentDialog}>
                Cancel
              </Button>
              <Button onClick={assignPermanently}>
                {assigningVehicle?.status === 'permanently_assigned' ? 'Update Assignment' : 'Assign Permanently'}
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}


