"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Plus, Pencil, Trash2 } from "lucide-react";
import { useToast } from "@/components/ui/use-toast";

type Office = { 
  _id: string; 
  name: string; 
  address?: string;
  coordinates?: { lat: number; lng: number };
  location?: { lat: number; lng: number };
  isHeadOffice?: boolean;
};

async function fetchJSON<T>(url: string): Promise<T> {
  const res = await fetch(url, { cache: "no-store" });
  if (!res.ok) throw new Error("Failed");
  return res.json();
}

export default function OfficesPage() {
  const qc = useQueryClient();
  const { success, error } = useToast();
  const { data: offices = [], isLoading } = useQuery<Office[]>({ queryKey: ["offices"], queryFn: () => fetchJSON<Office[]>("/api/offices") });

  const [showCreate, setShowCreate] = useState(false);
  const [editingOffice, setEditingOffice] = useState<Office | null>(null);
  const [form, setForm] = useState({ name: "", address: "", lat: "", lng: "", isHeadOffice: false });

  async function createOffice() {
    if (!form.name || !form.address || !form.lat || !form.lng) {
      error("Please fill all required fields");
      return;
    }
    const res = await fetch("/api/offices", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ 
        name: form.name, 
        address: form.address,
        coordinates: { lat: Number(form.lat), lng: Number(form.lng) },
        isHeadOffice: form.isHeadOffice,
      }),
    });
    if (res.ok) {
      setShowCreate(false);
      setForm({ name: "", address: "", lat: "", lng: "", isHeadOffice: false });
      qc.invalidateQueries({ queryKey: ["offices"] });
      success("Office created successfully");
    } else {
      const data = await res.json().catch(() => ({}));
      error(data.message || "Failed to create office");
    }
  }

  async function updateOffice() {
    if (!editingOffice || !form.name || !form.address || !form.lat || !form.lng) {
      error("Please fill all required fields");
      return;
    }
    const res = await fetch(`/api/offices/${editingOffice._id}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ 
        name: form.name, 
        address: form.address,
        coordinates: { lat: Number(form.lat), lng: Number(form.lng) },
        isHeadOffice: form.isHeadOffice,
      }),
    });
    if (res.ok) {
      setEditingOffice(null);
      setForm({ name: "", address: "", lat: "", lng: "", isHeadOffice: false });
      qc.invalidateQueries({ queryKey: ["offices"] });
      success("Office updated successfully");
    } else {
      const data = await res.json().catch(() => ({}));
      error(data.message || "Failed to update office");
    }
  }

  async function deleteOffice(id: string) {
    if (!confirm("Are you sure you want to delete this office?")) {
      return;
    }
    const res = await fetch(`/api/offices/${id}`, {
      method: "DELETE",
    });
    if (res.ok) {
      qc.invalidateQueries({ queryKey: ["offices"] });
      success("Office deleted successfully");
    } else {
      const data = await res.json().catch(() => ({}));
      error(data.message || "Failed to delete office");
    }
  }

  function openEditDialog(office: Office) {
    setEditingOffice(office);
    const coords = office.coordinates || office.location;
    setForm({
      name: office.name,
      address: office.address || "",
      lat: coords?.lat?.toString() || "",
      lng: coords?.lng?.toString() || "",
      isHeadOffice: office.isHeadOffice || false,
    });
  }

  function closeDialog() {
    setShowCreate(false);
    setEditingOffice(null);
    setForm({ name: "", address: "", lat: "", lng: "", isHeadOffice: false });
  }

  return (
    <div className="space-y-4">
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>Offices Management</CardTitle>
            <Dialog open={showCreate} onOpenChange={setShowCreate}>
              <DialogTrigger asChild>
                <Button>
                  <Plus className="mr-2 h-4 w-4" />
                  Create Office
                </Button>
              </DialogTrigger>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle>Create New Office</DialogTitle>
                </DialogHeader>
                <div className="space-y-4 py-4">
                  <div className="space-y-2">
                    <Label htmlFor="name">Office Name *</Label>
                    <Input
                      id="name"
                      placeholder="Main Office"
                      value={form.name}
                      onChange={(e) => setForm({ ...form, name: e.target.value })}
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="address">Address *</Label>
                    <Input
                      id="address"
                      placeholder="123 Main Street, City"
                      value={form.address}
                      onChange={(e) => setForm({ ...form, address: e.target.value })}
                    />
                  </div>
                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <Label htmlFor="lat">Latitude *</Label>
                      <Input
                        id="lat"
                        type="number"
                        step="any"
                        placeholder="6.5244"
                        value={form.lat}
                        onChange={(e) => setForm({ ...form, lat: e.target.value })}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="lng">Longitude *</Label>
                      <Input
                        id="lng"
                        type="number"
                        step="any"
                        placeholder="3.3792"
                        value={form.lng}
                        onChange={(e) => setForm({ ...form, lng: e.target.value })}
                      />
                    </div>
                  </div>
                  <div className="flex items-center space-x-2">
                    <input
                      type="checkbox"
                      id="isHeadOffice"
                      checked={form.isHeadOffice}
                      onChange={(e) => setForm({ ...form, isHeadOffice: e.target.checked })}
                      className="h-4 w-4"
                    />
                    <Label htmlFor="isHeadOffice">Is Head Office</Label>
                  </div>
                  <div className="flex gap-2 justify-end">
                    <Button variant="outline" onClick={closeDialog}>
                      Cancel
                    </Button>
                    <Button onClick={createOffice}>Create</Button>
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
                <TableHead>Name</TableHead>
                <TableHead>Address</TableHead>
                <TableHead>Coordinates</TableHead>
                <TableHead>Type</TableHead>
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
              ) : offices.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={5} className="text-center">
                    No offices found
                  </TableCell>
                </TableRow>
              ) : (
                offices.map((o) => {
                  const coords = o.coordinates || o.location;
                  return (
                    <TableRow key={o._id}>
                      <TableCell className="font-medium">{o.name}</TableCell>
                      <TableCell>{o.address ?? "N/A"}</TableCell>
                      <TableCell>
                        {coords ? `${coords.lat?.toFixed(6)}, ${coords.lng?.toFixed(6)}` : "N/A"}
                      </TableCell>
                      <TableCell>{o.isHeadOffice ? "Head Office" : "Branch"}</TableCell>
                      <TableCell>
                        <div className="flex gap-2">
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => openEditDialog(o)}
                          >
                            <Pencil className="h-4 w-4" />
                          </Button>
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => deleteOffice(o._id)}
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
      <Dialog open={!!editingOffice} onOpenChange={(open) => !open && closeDialog()}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Edit Office</DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="edit-name">Office Name *</Label>
              <Input
                id="edit-name"
                placeholder="Main Office"
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="edit-address">Address *</Label>
              <Input
                id="edit-address"
                placeholder="123 Main Street, City"
                value={form.address}
                onChange={(e) => setForm({ ...form, address: e.target.value })}
              />
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="edit-lat">Latitude *</Label>
                <Input
                  id="edit-lat"
                  type="number"
                  step="any"
                  placeholder="6.5244"
                  value={form.lat}
                  onChange={(e) => setForm({ ...form, lat: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="edit-lng">Longitude *</Label>
                <Input
                  id="edit-lng"
                  type="number"
                  step="any"
                  placeholder="3.3792"
                  value={form.lng}
                  onChange={(e) => setForm({ ...form, lng: e.target.value })}
                />
              </div>
            </div>
            <div className="flex items-center space-x-2">
              <input
                type="checkbox"
                id="edit-isHeadOffice"
                checked={form.isHeadOffice}
                onChange={(e) => setForm({ ...form, isHeadOffice: e.target.checked })}
                className="h-4 w-4"
              />
              <Label htmlFor="edit-isHeadOffice">Is Head Office</Label>
            </div>
            <div className="flex gap-2 justify-end">
              <Button variant="outline" onClick={closeDialog}>
                Cancel
              </Button>
              <Button onClick={updateOffice}>Update</Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}


