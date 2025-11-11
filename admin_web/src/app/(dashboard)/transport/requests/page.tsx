"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { useToast } from "@/components/ui/use-toast";
import { VehicleQuickLinks } from "@/components/transport/VehicleQuickLinks";

type RequestItem = {
  _id: string;
  destination?: string;
  purpose?: string;
  startDate?: string;
  status: string;
};

async function fetchJSON<T>(url: string): Promise<T> {
  const res = await fetch(url, { cache: "no-store" });
  if (!res.ok) throw new Error("Failed to load");
  return res.json();
}

export default function TransportRequestsPage() {
  const qc = useQueryClient();
  const { success, error } = useToast();
  const [filter, setFilter] = useState<string>("all");
  const [approveDialog, setApproveDialog] = useState<{ open: boolean; id: string | null }>({ open: false, id: null });
  const [rejectDialog, setRejectDialog] = useState<{ open: boolean; id: string | null }>({ open: false, id: null });
  const [assignDialog, setAssignDialog] = useState<{ open: boolean; id: string | null }>({ open: false, id: null });
  const [comments, setComments] = useState("");
  const [rejectionReason, setRejectionReason] = useState("");
  const [selectedDriver, setSelectedDriver] = useState("");
  const [selectedVehicle, setSelectedVehicle] = useState("");
  const [drivers, setDrivers] = useState<any[]>([]);
  const [vehicles, setVehicles] = useState<any[]>([]);

  const { data: requests = [], isLoading } = useQuery<RequestItem[]>({
    queryKey: ["transport-requests"],
    queryFn: () => fetchJSON<RequestItem[]>("/api/transport/requests"),
  });

  const filtered = requests.filter((r) => (filter === "all" ? true : r.status === filter));

  async function approve(id: string) {
    const res = await fetch(`/api/transport/requests/${id}/approve`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ comments: comments || undefined }),
    });
    if (res.ok) {
      qc.invalidateQueries({ queryKey: ["transport-requests"] });
      setApproveDialog({ open: false, id: null });
      setComments("");
      success("Request approved successfully");
    } else {
      const data = await res.json().catch(() => ({}));
      error(data.message || "Failed to approve");
    }
  }

  async function reject(id: string) {
    if (!rejectionReason) {
      error("Please provide a rejection reason");
      return;
    }
    const res = await fetch(`/api/transport/requests/${id}/reject`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ rejectionReason }),
    });
    if (res.ok) {
      qc.invalidateQueries({ queryKey: ["transport-requests"] });
      setRejectDialog({ open: false, id: null });
      setRejectionReason("");
      success("Request rejected successfully");
    } else {
      const data = await res.json().catch(() => ({}));
      error(data.message || "Failed to reject");
    }
  }

  async function openAssignDialog(id: string) {
    const driversData: any[] = await fetchJSON("/api/assignments/available-drivers");
    const vehiclesData: any[] = await fetchJSON("/api/assignments/available-vehicles");
    if (!driversData.length || !vehiclesData.length) {
      error("No available drivers or vehicles");
      return;
    }
    setDrivers(driversData);
    setVehicles(vehiclesData);
    setSelectedDriver(driversData[0]?._id || "");
    setSelectedVehicle(vehiclesData[0]?._id || "");
    setAssignDialog({ open: true, id });
  }

  async function assign() {
    if (!assignDialog.id || !selectedDriver || !selectedVehicle) {
      error("Please select both driver and vehicle");
      return;
    }
    const res = await fetch(`/api/assignments/assign`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ requestId: assignDialog.id, driverId: selectedDriver, vehicleId: selectedVehicle }),
    });
    if (res.ok) {
      qc.invalidateQueries({ queryKey: ["transport-requests"] });
      setAssignDialog({ open: false, id: null });
      setSelectedDriver("");
      setSelectedVehicle("");
      success("Driver and vehicle assigned successfully");
    } else {
      const data = await res.json().catch(() => ({}));
      error(data.message || "Failed to assign");
    }
  }

  const getStatusVariant = (status: string) => {
    if (status.includes("approved")) return "default";
    if (status === "pending") return "secondary";
    if (status === "rejected") return "destructive";
    if (status === "completed") return "outline";
    if (status === "in_progress") return "default";
    return "outline";
  };

  const getStatusLabel = (status: string) => {
    return status
      .split("_")
      .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
      .join(" ");
  };

  return (
    <div className="space-y-4">
      <VehicleQuickLinks />
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>Transport Requests Management</CardTitle>
            <div className="flex items-center gap-2">
              <span className="text-sm text-muted-foreground">Filter:</span>
              <Select value={filter} onValueChange={setFilter}>
                <SelectTrigger className="w-[180px]">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All</SelectItem>
                  <SelectItem value="pending">Pending</SelectItem>
                  <SelectItem value="supervisor_approved">Supervisor Approved</SelectItem>
                  <SelectItem value="dgs_approved">DGS Approved</SelectItem>
                  <SelectItem value="ddgs_approved">DDGS Approved</SelectItem>
                  <SelectItem value="ad_transport_approved">AD Transport Approved</SelectItem>
                  <SelectItem value="transport_officer_assigned">Transport Officer Assigned</SelectItem>
                  <SelectItem value="driver_accepted">Driver Accepted</SelectItem>
                  <SelectItem value="in_progress">In Progress</SelectItem>
                  <SelectItem value="completed">Completed</SelectItem>
                  <SelectItem value="returned">Returned</SelectItem>
                  <SelectItem value="rejected">Rejected</SelectItem>
                  <SelectItem value="needs_correction">Needs Correction</SelectItem>
                  <SelectItem value="cancelled">Cancelled</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Destination</TableHead>
                <TableHead>Purpose</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Date</TableHead>
                <TableHead>Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {isLoading ? (
                <TableRow>
                  <TableCell colSpan={5} className="text-center">
                    Loading...
                  </TableCell>
                </TableRow>
              ) : filtered.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={5} className="text-center">
                    No requests found
                  </TableCell>
                </TableRow>
              ) : (
                filtered.map((r) => (
                  <TableRow key={r._id}>
                    <TableCell className="font-medium">{r.destination ?? "Unknown"}</TableCell>
                    <TableCell>{r.purpose ?? ""}</TableCell>
                    <TableCell>
                      <Badge variant={getStatusVariant(r.status)}>{getStatusLabel(r.status)}</Badge>
                    </TableCell>
                    <TableCell>
                      {r.startDate
                        ? new Date(r.startDate).toLocaleDateString("en-US", {
                            year: "numeric",
                            month: "short",
                            day: "numeric",
                          })
                        : "N/A"}
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center gap-2">
                        {["pending", "supervisor_approved", "dgs_approved", "ddgs_approved", "ad_transport_approved"].includes(
                          r.status
                        ) && (
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => setApproveDialog({ open: true, id: r._id })}
                          >
                            Approve
                          </Button>
                        )}
                        {r.status === "ad_transport_approved" && (
                          <Button variant="outline" size="sm" onClick={() => openAssignDialog(r._id)}>
                            Assign
                          </Button>
                        )}
                        <Button variant="outline" size="sm" onClick={() => setRejectDialog({ open: true, id: r._id })}>
                          Reject
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      {/* Approve Dialog */}
      <Dialog open={approveDialog.open} onOpenChange={(open) => setApproveDialog({ open, id: null })}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Approve Request</DialogTitle>
            <DialogDescription>Add optional comments for this approval</DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="comments">Comments (optional)</Label>
              <Textarea
                id="comments"
                placeholder="Enter comments..."
                value={comments}
                onChange={(e) => setComments(e.target.value)}
              />
            </div>
            <div className="flex gap-2 justify-end">
              <Button variant="outline" onClick={() => setApproveDialog({ open: false, id: null })}>
                Cancel
              </Button>
              <Button onClick={() => approve(approveDialog.id!)}>Approve</Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>

      {/* Reject Dialog */}
      <Dialog open={rejectDialog.open} onOpenChange={(open) => setRejectDialog({ open, id: null })}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Reject Request</DialogTitle>
            <DialogDescription>Please provide a reason for rejection</DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="rejectionReason">Rejection Reason *</Label>
              <Textarea
                id="rejectionReason"
                placeholder="Enter rejection reason..."
                value={rejectionReason}
                onChange={(e) => setRejectionReason(e.target.value)}
                required
              />
            </div>
            <div className="flex gap-2 justify-end">
              <Button variant="outline" onClick={() => setRejectDialog({ open: false, id: null })}>
                Cancel
              </Button>
              <Button variant="destructive" onClick={() => reject(rejectDialog.id!)}>
                Reject
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>

      {/* Assign Dialog */}
      <Dialog open={assignDialog.open} onOpenChange={(open) => setAssignDialog({ open, id: null })}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Assign Driver and Vehicle</DialogTitle>
            <DialogDescription>Select a driver and vehicle for this request</DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="driver">Driver *</Label>
              <Select value={selectedDriver} onValueChange={setSelectedDriver}>
                <SelectTrigger id="driver">
                  <SelectValue placeholder="Select a driver" />
                </SelectTrigger>
                <SelectContent>
                  {drivers.map((d) => (
                    <SelectItem key={d._id} value={d._id}>
                      {d.name} ({d.email})
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label htmlFor="vehicle">Vehicle *</Label>
              <Select value={selectedVehicle} onValueChange={setSelectedVehicle}>
                <SelectTrigger id="vehicle">
                  <SelectValue placeholder="Select a vehicle" />
                </SelectTrigger>
                <SelectContent>
                  {vehicles.map((v) => (
                    <SelectItem key={v._id} value={v._id}>
                      {v.plateNumber} - {v.make} {v.model}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="flex gap-2 justify-end">
              <Button variant="outline" onClick={() => setAssignDialog({ open: false, id: null })}>
                Cancel
              </Button>
              <Button onClick={assign}>Assign</Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}

