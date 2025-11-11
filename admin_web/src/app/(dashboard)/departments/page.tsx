"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Textarea } from "@/components/ui/textarea";
import { Plus, Pencil, Trash2 } from "lucide-react";
import { useToast } from "@/components/ui/use-toast";

type Department = {
  _id: string;
  name: string;
  description?: string;
};

async function fetchJSON<T>(url: string): Promise<T> {
  const res = await fetch(url, { cache: "no-store" });
  if (!res.ok) throw new Error("Failed");
  return res.json();
}

export default function DepartmentsPage() {
  const qc = useQueryClient();
  const { success, error } = useToast();
  const { data: departments = [], isLoading } = useQuery<Department[]>({
    queryKey: ["departments"],
    queryFn: () => fetchJSON<Department[]>("/api/departments"),
  });

  const [showCreate, setShowCreate] = useState(false);
  const [editingDept, setEditingDept] = useState<Department | null>(null);
  const [form, setForm] = useState({ name: "", description: "" });

  async function createDepartment() {
    if (!form.name.trim()) {
      error("Department name is required");
      return;
    }
    const res = await fetch("/api/departments", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        name: form.name.trim(),
        description: form.description.trim() || undefined,
      }),
    });
    if (res.ok) {
      setShowCreate(false);
      setForm({ name: "", description: "" });
      qc.invalidateQueries({ queryKey: ["departments"] });
      success("Department created successfully");
    } else {
      const data = await res.json().catch(() => ({}));
      error(data.message || "Failed to create department");
    }
  }

  async function updateDepartment() {
    if (!editingDept || !form.name.trim()) {
      error("Department name is required");
      return;
    }
    const res = await fetch(`/api/departments/${editingDept._id}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        name: form.name.trim(),
        description: form.description.trim() || undefined,
      }),
    });
    if (res.ok) {
      setEditingDept(null);
      setForm({ name: "", description: "" });
      qc.invalidateQueries({ queryKey: ["departments"] });
      success("Department updated successfully");
    } else {
      const data = await res.json().catch(() => ({}));
      error(data.message || "Failed to update department");
    }
  }

  async function deleteDepartment(id: string) {
    if (!confirm("Are you sure you want to delete this department?")) {
      return;
    }
    const res = await fetch(`/api/departments/${id}`, {
      method: "DELETE",
    });
    if (res.ok) {
      qc.invalidateQueries({ queryKey: ["departments"] });
      success("Department deleted successfully");
    } else {
      const data = await res.json().catch(() => ({}));
      error(data.message || "Failed to delete department");
    }
  }

  function openEditDialog(dept: Department) {
    setEditingDept(dept);
    setForm({ name: dept.name, description: dept.description || "" });
  }

  function closeDialog() {
    setShowCreate(false);
    setEditingDept(null);
    setForm({ name: "", description: "" });
  }

  return (
    <div className="space-y-4">
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>Departments Management</CardTitle>
            <Dialog open={showCreate} onOpenChange={setShowCreate}>
              <DialogTrigger asChild>
                <Button onClick={() => setForm({ name: "", description: "" })}>
                  <Plus className="mr-2 h-4 w-4" />
                  Create Department
                </Button>
              </DialogTrigger>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle>Create New Department</DialogTitle>
                </DialogHeader>
                <div className="space-y-4 py-4">
                  <div className="space-y-2">
                    <Label htmlFor="dept-name">Department Name *</Label>
                    <Input
                      id="dept-name"
                      placeholder="e.g., IT, HR, Finance"
                      value={form.name}
                      onChange={(e) => setForm({ ...form, name: e.target.value })}
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="dept-description">Description (optional)</Label>
                    <Textarea
                      id="dept-description"
                      placeholder="Enter department description..."
                      value={form.description}
                      onChange={(e) => setForm({ ...form, description: e.target.value })}
                      rows={3}
                    />
                  </div>
                  <div className="flex gap-2 justify-end">
                    <Button variant="outline" onClick={closeDialog}>
                      Cancel
                    </Button>
                    <Button onClick={createDepartment}>Create</Button>
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
                <TableHead>Description</TableHead>
                <TableHead>Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {isLoading ? (
                <TableRow>
                  <TableCell colSpan={3} className="text-center">
                    Loading...
                  </TableCell>
                </TableRow>
              ) : departments.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={3} className="text-center">
                    No departments found
                  </TableCell>
                </TableRow>
              ) : (
                departments.map((dept) => (
                  <TableRow key={dept._id}>
                    <TableCell className="font-medium">{dept.name}</TableCell>
                    <TableCell>{dept.description || "—"}</TableCell>
                    <TableCell>
                      <div className="flex gap-2">
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => openEditDialog(dept)}
                        >
                          <Pencil className="h-4 w-4" />
                        </Button>
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => deleteDepartment(dept._id)}
                        >
                          <Trash2 className="h-4 w-4" />
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

      {/* Edit Dialog */}
      <Dialog open={!!editingDept} onOpenChange={(open) => !open && closeDialog()}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Edit Department</DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="edit-dept-name">Department Name *</Label>
              <Input
                id="edit-dept-name"
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="edit-dept-description">Description (optional)</Label>
              <Textarea
                id="edit-dept-description"
                value={form.description}
                onChange={(e) => setForm({ ...form, description: e.target.value })}
                rows={3}
              />
            </div>
            <div className="flex gap-2 justify-end">
              <Button variant="outline" onClick={closeDialog}>
                Cancel
              </Button>
              <Button onClick={updateDepartment}>Update</Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}

