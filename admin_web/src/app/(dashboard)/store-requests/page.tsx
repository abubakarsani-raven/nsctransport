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
import { StoreRequest, StoreRequestStatus, STORE_STATUS_LABELS } from "@/types/store-request";

async function fetchJSON<T>(url: string): Promise<T> {
  const res = await fetch(url, { cache: "no-store" });
  if (!res.ok) throw new Error("Failed to load");
  return res.json();
}

export default function StoreRequestsPage() {
  const qc = useQueryClient();
  const { success, error } = useToast();
  const [filter, setFilter] = useState<string>("all");
  const [approveDialog, setApproveDialog] = useState<{ open: boolean; id: string | null }>({ open: false, id: null });
  const [rejectDialog, setRejectDialog] = useState<{ open: boolean; id: string | null }>({ open: false, id: null });
  const [sendBackDialog, setSendBackDialog] = useState<{ open: boolean; id: string | null }>({ open: false, id: null });
  const [cancelDialog, setCancelDialog] = useState<{ open: boolean; id: string | null }>({ open: false, id: null });
  const [comments, setComments] = useState("");
  const [rejectionReason, setRejectionReason] = useState("");
  const [correctionReason, setCorrectionReason] = useState("");
  const [cancelReason, setCancelReason] = useState("");

  const { data: requests = [], isLoading } = useQuery<StoreRequest[]>({
    queryKey: ["store-requests"],
    queryFn: () => fetchJSON<StoreRequest[]>("/api/store-requests"),
  });

  const filtered = requests.filter((r) => (filter === "all" ? true : r.status === filter));

  async function approve(id: string) {
    const res = await fetch(`/api/store-requests/${id}/approve`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ comments: comments || undefined }),
    });
    if (res.ok) {
      qc.invalidateQueries({ queryKey: ["store-requests"] });
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
    const res = await fetch(`/api/store-requests/${id}/reject`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ rejectionReason }),
    });
    if (res.ok) {
      qc.invalidateQueries({ queryKey: ["store-requests"] });
      setRejectDialog({ open: false, id: null });
      setRejectionReason("");
      success("Request rejected successfully");
    } else {
      const data = await res.json().catch(() => ({}));
      error(data.message || "Failed to reject");
    }
  }

  async function sendBack(id: string) {
    if (!correctionReason) {
      error("Please provide a correction reason");
      return;
    }
    const res = await fetch(`/api/store-requests/${id}/send-back`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ correctionReason, comments: comments || undefined }),
    });
    if (res.ok) {
      qc.invalidateQueries({ queryKey: ["store-requests"] });
      setSendBackDialog({ open: false, id: null });
      setCorrectionReason("");
      setComments("");
      success("Request sent back for correction successfully");
    } else {
      const data = await res.json().catch(() => ({}));
      error(data.message || "Failed to send back");
    }
  }

  async function cancel(id: string) {
    if (!cancelReason) {
      error("Please provide a cancellation reason");
      return;
    }
    const res = await fetch(`/api/store-requests/${id}/cancel`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ reason: cancelReason }),
    });
    if (res.ok) {
      qc.invalidateQueries({ queryKey: ["store-requests"] });
      setCancelDialog({ open: false, id: null });
      setCancelReason("");
      success("Request cancelled successfully");
    } else {
      const data = await res.json().catch(() => ({}));
      error(data.message || "Failed to cancel");
    }
  }

  const getStatusVariant = (status: string) => {
    if (status.includes("approved")) return "default";
    if (status === "store_pending") return "secondary";
    if (status === "store_rejected") return "destructive";
    if (status === "store_fulfilled") return "outline";
    if (status === "store_needs_correction") return "destructive";
    return "outline";
  };

  const getRequesterName = (requesterId: any) => {
    if (typeof requesterId === "object" && requesterId?.name) {
      return requesterId.name;
    }
    return "Unknown";
  };

  return (
    <div className="space-y-4">
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>Store Requests Management</CardTitle>
            <div className="flex items-center gap-2">
              <span className="text-sm text-muted-foreground">Filter:</span>
              <Select value={filter} onValueChange={setFilter}>
                <SelectTrigger className="w-[200px]">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All</SelectItem>
                  <SelectItem value={StoreRequestStatus.PENDING}>Pending</SelectItem>
                  <SelectItem value={StoreRequestStatus.SUPERVISOR_APPROVED}>Supervisor Approved</SelectItem>
                  <SelectItem value={StoreRequestStatus.STORE_OFFICER_APPROVED}>Store Officer Approved</SelectItem>
                  <SelectItem value={StoreRequestStatus.APPROVED}>Approved</SelectItem>
                  <SelectItem value={StoreRequestStatus.REJECTED}>Rejected</SelectItem>
                  <SelectItem value={StoreRequestStatus.NEEDS_CORRECTION}>Needs Correction</SelectItem>
                  <SelectItem value={StoreRequestStatus.CANCELLED}>Cancelled</SelectItem>
                  <SelectItem value={StoreRequestStatus.FULFILLED}>Fulfilled</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Item Name</TableHead>
                <TableHead>Category</TableHead>
                <TableHead>Quantity</TableHead>
                <TableHead>Unit</TableHead>
                <TableHead>Purpose</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Requester</TableHead>
                <TableHead>Date</TableHead>
                <TableHead>Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {isLoading ? (
                <TableRow>
                  <TableCell colSpan={9} className="text-center">
                    Loading...
                  </TableCell>
                </TableRow>
              ) : filtered.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={9} className="text-center">
                    No requests found
                  </TableCell>
                </TableRow>
              ) : (
                filtered.map((r) => (
                  <TableRow key={r._id}>
                    <TableCell className="font-medium">{r.itemName}</TableCell>
                    <TableCell>{r.category || "N/A"}</TableCell>
                    <TableCell>{r.quantity}</TableCell>
                    <TableCell>{r.unit || "N/A"}</TableCell>
                    <TableCell>{r.purpose}</TableCell>
                    <TableCell>
                      <Badge variant={getStatusVariant(r.status)}>{STORE_STATUS_LABELS[r.status as StoreRequestStatus] || r.status}</Badge>
                    </TableCell>
                    <TableCell>{getRequesterName(r.requesterId)}</TableCell>
                    <TableCell>
                      {r.createdAt
                        ? new Date(r.createdAt).toLocaleDateString("en-US", {
                            year: "numeric",
                            month: "short",
                            day: "numeric",
                          })
                        : "N/A"}
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center gap-2">
                        {[
                          StoreRequestStatus.PENDING,
                          StoreRequestStatus.SUPERVISOR_APPROVED,
                          StoreRequestStatus.STORE_OFFICER_APPROVED,
                        ].includes(r.status as StoreRequestStatus) && (
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => setApproveDialog({ open: true, id: r._id })}
                          >
                            Approve
                          </Button>
                        )}
                        {[
                          StoreRequestStatus.PENDING,
                          StoreRequestStatus.SUPERVISOR_APPROVED,
                          StoreRequestStatus.STORE_OFFICER_APPROVED,
                        ].includes(r.status as StoreRequestStatus) && (
                          <Button variant="outline" size="sm" onClick={() => setSendBackDialog({ open: true, id: r._id })}>
                            Send Back
                          </Button>
                        )}
                        {[
                          StoreRequestStatus.PENDING,
                          StoreRequestStatus.SUPERVISOR_APPROVED,
                          StoreRequestStatus.STORE_OFFICER_APPROVED,
                        ].includes(r.status as StoreRequestStatus) && (
                          <Button variant="outline" size="sm" onClick={() => setRejectDialog({ open: true, id: r._id })}>
                            Reject
                          </Button>
                        )}
                        {[
                          StoreRequestStatus.PENDING,
                          StoreRequestStatus.SUPERVISOR_APPROVED,
                          StoreRequestStatus.STORE_OFFICER_APPROVED,
                        ].includes(r.status as StoreRequestStatus) && (
                          <Button variant="outline" size="sm" onClick={() => setCancelDialog({ open: true, id: r._id })}>
                            Cancel
                          </Button>
                        )}
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

      {/* Send Back Dialog */}
      <Dialog open={sendBackDialog.open} onOpenChange={(open) => setSendBackDialog({ open, id: null })}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Send Back for Correction</DialogTitle>
            <DialogDescription>Please provide a reason for sending back</DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="correctionReason">Correction Reason *</Label>
              <Textarea
                id="correctionReason"
                placeholder="Enter correction reason..."
                value={correctionReason}
                onChange={(e) => setCorrectionReason(e.target.value)}
                required
              />
            </div>
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
              <Button variant="outline" onClick={() => setSendBackDialog({ open: false, id: null })}>
                Cancel
              </Button>
              <Button onClick={() => sendBack(sendBackDialog.id!)}>Send Back</Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>

      {/* Cancel Dialog */}
      <Dialog open={cancelDialog.open} onOpenChange={(open) => setCancelDialog({ open, id: null })}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Cancel Request</DialogTitle>
            <DialogDescription>Please provide a reason for cancellation</DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="cancelReason">Cancellation Reason *</Label>
              <Textarea
                id="cancelReason"
                placeholder="Enter cancellation reason..."
                value={cancelReason}
                onChange={(e) => setCancelReason(e.target.value)}
                required
              />
            </div>
            <div className="flex gap-2 justify-end">
              <Button variant="outline" onClick={() => setCancelDialog({ open: false, id: null })}>
                Cancel
              </Button>
              <Button variant="destructive" onClick={() => cancel(cancelDialog.id!)}>
                Cancel Request
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}

