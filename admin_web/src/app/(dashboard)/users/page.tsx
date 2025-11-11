"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Checkbox } from "@/components/ui/checkbox";
import { useToast } from "@/components/ui/use-toast";
import { Pencil } from "lucide-react";

type User = { _id: string; name: string; email: string; phone?: string; department?: string; role?: string; roles?: string[]; employeeId?: string; isSupervisor?: boolean };
type Department = { _id: string; name: string; description?: string };

async function fetchJSON<T>(url: string): Promise<T> {
  const res = await fetch(url, { cache: "no-store" });
  if (!res.ok) throw new Error("Failed");
  return res.json();
}

export default function UsersPage() {
  const qc = useQueryClient();
  const { success, error } = useToast();
  const [showCreateUser, setShowCreateUser] = useState(false);
  const [userForm, setUserForm] = useState({ 
    name: "", 
    email: "", 
    phone: "", 
    password: "", 
    department: "", 
    isSupervisor: false, 
    roles: ["staff"] as string[],
    employeeId: ""
  });
  const [editingUser, setEditingUser] = useState<User | null>(null);
  const [editUserForm, setEditUserForm] = useState({ 
    name: "", 
    phone: "", 
    password: "", 
    department: "", 
    isSupervisor: false, 
    roles: [] as string[],
    employeeId: ""
  });

  const allUsersQ = useQuery<User[]>({ 
    queryKey: ["allUsers"], 
    queryFn: async () => {
      const res = await fetch("/api/users", { cache: "no-store" });
      if (res.status === 403) {
        // Try to bootstrap admin role
        const bootstrapRes = await fetch("/api/users/bootstrap-admin", { cache: "no-store" });
        if (bootstrapRes.ok) {
          const bootstrapData = await bootstrapRes.json();
          success(`Admin role added: ${bootstrapData.message}`);
          // Retry fetching users
          const retryRes = await fetch("/api/users", { cache: "no-store" });
          if (retryRes.ok) {
            return retryRes.json();
          }
        }
        throw new Error("Forbidden: Admin role required");
      }
      if (!res.ok) throw new Error("Failed to fetch users");
      return res.json();
    },
    retry: false,
  });
  const departmentsQ = useQuery<Department[]>({ queryKey: ["departments"], queryFn: () => fetchJSON<Department[]>("/api/departments") });

  async function createUser() {
    if (!userForm.name || !userForm.email || !userForm.phone || !userForm.password) {
      error('Please fill all required fields');
      return;
    }
    if (userForm.roles.length === 0) {
      error('Please select at least one role');
      return;
    }
    if (userForm.password.length < 6) {
      error('Password must be at least 6 characters');
      return;
    }
    // Validate department if staff role is selected
    if (userForm.roles.includes('staff') && !userForm.department) {
      error('Department is required for staff role');
      return;
    }
    
    const res = await fetch('/api/auth/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        name: userForm.name, 
        email: userForm.email, 
        phone: userForm.phone, 
        password: userForm.password, 
        roles: userForm.roles,
        department: userForm.department || undefined,
        isSupervisor: userForm.isSupervisor,
        employeeId: (userForm.roles.includes('driver') || userForm.roles.includes('staff')) ? (userForm.employeeId || undefined) : undefined,
      }),
    });
    if (res.ok) {
      setShowCreateUser(false);
      setUserForm({ name: "", email: "", phone: "", password: "", department: "", isSupervisor: false, roles: ["staff"], employeeId: "" });
      qc.invalidateQueries({ queryKey: ["allUsers"] });
      success('User created successfully');
    } else {
      const data = await res.json().catch(() => ({}));
      error(data.message || 'Failed to create user');
    }
  }

  async function updateUser() {
    if (!editingUser || !editUserForm.name || !editUserForm.phone) {
      error('Please fill all required fields');
      return;
    }
    if (editUserForm.password && editUserForm.password.length < 6) {
      error('Password must be at least 6 characters');
      return;
    }
    if (editUserForm.roles.length === 0) {
      error('Please select at least one role');
      return;
    }
    const updateData: any = {
      name: editUserForm.name,
      phone: editUserForm.phone,
      roles: editUserForm.roles, // Ensure roles array is sent
    };
    if (editUserForm.password) {
      updateData.password = editUserForm.password;
    }
    // Only require department if user has staff role
    if (editUserForm.roles.includes('staff')) {
      if (!editUserForm.department) {
        error('Department is required for staff');
        return;
      }
    }
    updateData.department = editUserForm.department || undefined;
    updateData.isSupervisor = editUserForm.isSupervisor;
    if (editUserForm.roles.includes('driver') || editUserForm.roles.includes('staff')) {
      updateData.employeeId = editUserForm.employeeId || undefined;
    }
    
    console.log('Updating user with data:', updateData); // Debug log
    
    const res = await fetch(`/api/users/${editingUser._id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(updateData),
    });
    if (res.ok) {
      const updatedData = await res.json().catch(() => ({}));
      console.log('User updated successfully:', updatedData); // Debug log
      setEditingUser(null);
      setEditUserForm({ name: "", phone: "", password: "", department: "", isSupervisor: false, roles: ["staff"], employeeId: "" });
      qc.invalidateQueries({ queryKey: ["allUsers"] });
      success('User updated successfully');
    } else {
      const data = await res.json().catch(() => ({}));
      const errorMessage = data.message || 'Failed to update user';
      console.error('Update error:', errorMessage, data); // Debug log
      error(errorMessage);
    }
  }

  function openEditUserDialog(user: User) {
    setEditingUser(user);
    // Get roles from roles array or fallback to single role (backward compatibility)
    const userRoles = user.roles && user.roles.length > 0 ? user.roles : (user.role ? [user.role] : []);
    setEditUserForm({
      name: user.name,
      phone: user.phone || "",
      password: "",
      department: user.department || "",
      isSupervisor: user.isSupervisor || false,
      roles: userRoles,
      employeeId: user.employeeId || "",
    });
  }

  // Helper function to get display roles
  function getDisplayRoles(user: User): string[] {
    return user.roles && user.roles.length > 0 ? user.roles : (user.role ? [user.role] : []);
  }

  // Helper function to get role badge color
  function getRoleBadgeColor(role: string): string {
    const colors: Record<string, string> = {
      staff: 'bg-blue-100 text-blue-800',
      driver: 'bg-green-100 text-green-800',
      transport_officer: 'bg-purple-100 text-purple-800',
      dgs: 'bg-yellow-100 text-yellow-800',
      ddgs: 'bg-orange-100 text-orange-800',
      ad_transport: 'bg-red-100 text-red-800',
      admin: 'bg-gray-100 text-gray-800',
    };
    return colors[role] || 'bg-gray-100 text-gray-800';
  }

  const rows = allUsersQ.data ?? [];

  return (
    <div className="space-y-4">
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>Users Management</CardTitle>
            <Dialog open={showCreateUser} onOpenChange={setShowCreateUser}>
              <DialogTrigger asChild>
                <Button>Create User</Button>
              </DialogTrigger>
              <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
                <DialogHeader>
                  <DialogTitle>Create User</DialogTitle>
                </DialogHeader>
                <div className="space-y-4 py-4">
                  <div className="space-y-2">
                    <Label htmlFor="user-name">Name *</Label>
                    <Input id="user-name" value={userForm.name} onChange={(e) => setUserForm({ ...userForm, name: e.target.value })} />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="user-email">Email *</Label>
                    <Input id="user-email" type="email" value={userForm.email} onChange={(e) => setUserForm({ ...userForm, email: e.target.value })} />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="user-phone">Phone *</Label>
                    <Input id="user-phone" value={userForm.phone} onChange={(e) => setUserForm({ ...userForm, phone: e.target.value })} />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="user-password">Password *</Label>
                    <Input id="user-password" type="password" value={userForm.password} onChange={(e) => setUserForm({ ...userForm, password: e.target.value })} />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="user-roles">Roles * (Select multiple)</Label>
                    <div className="space-y-2 border rounded-md p-3 max-h-48 overflow-y-auto">
                      {['staff', 'driver', 'transport_officer', 'dgs', 'ddgs', 'ad_transport', 'admin'].map((role) => (
                        <div key={role} className="flex items-center space-x-2">
                          <Checkbox
                            id={`user-role-${role}`}
                            checked={userForm.roles.includes(role)}
                            onCheckedChange={(checked) => {
                              const currentRoles = [...userForm.roles];
                              if (checked) {
                                if (!currentRoles.includes(role)) {
                                  setUserForm({ ...userForm, roles: [...currentRoles, role] });
                                }
                              } else {
                                setUserForm({ ...userForm, roles: currentRoles.filter(r => r !== role) });
                              }
                            }}
                          />
                          <Label htmlFor={`user-role-${role}`} className="cursor-pointer capitalize">
                            {role.replace('_', ' ')}
                          </Label>
                        </div>
                      ))}
                    </div>
                    {userForm.roles.length === 0 && (
                      <p className="text-xs text-red-500">Please select at least one role</p>
                    )}
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="user-department">Department {userForm.roles.includes('staff') ? '*' : ''}</Label>
                    <Select
                      value={userForm.department}
                      onValueChange={(value) => setUserForm({ ...userForm, department: value })}
                    >
                      <SelectTrigger id="user-department">
                        <SelectValue placeholder="Select a department" />
                      </SelectTrigger>
                      <SelectContent>
                        {departmentsQ.data?.map((dept) => (
                          <SelectItem key={dept._id} value={dept.name}>
                            {dept.name}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                    {departmentsQ.data?.length === 0 && (
                      <p className="text-xs text-muted-foreground">
                        No departments available. Please create a department first.
                      </p>
                    )}
                  </div>
                  <div className="flex items-center space-x-2">
                    <Checkbox
                      id="user-supervisor"
                      checked={userForm.isSupervisor}
                      onCheckedChange={(checked) => setUserForm({ ...userForm, isSupervisor: checked === true })}
                    />
                    <Label htmlFor="user-supervisor" className="cursor-pointer">Is Supervisor</Label>
                  </div>
                  {(userForm.roles.includes('driver') || userForm.roles.includes('staff')) && (
                    <div className="space-y-2">
                      <Label htmlFor="user-employeeId">Employee ID (optional)</Label>
                      <Input id="user-employeeId" value={userForm.employeeId} onChange={(e) => setUserForm({ ...userForm, employeeId: e.target.value })} />
                    </div>
                  )}
                  <div className="flex gap-2 justify-end">
                    <Button variant="outline" onClick={() => setShowCreateUser(false)}>Cancel</Button>
                    <Button onClick={createUser}>Create</Button>
                  </div>
                </div>
              </DialogContent>
            </Dialog>
          </div>
        </CardHeader>
        <CardContent>
          <div className="mt-4">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Name</TableHead>
                  <TableHead>Email</TableHead>
                  <TableHead>Phone</TableHead>
                  <TableHead>Department</TableHead>
                  <TableHead>Employee ID</TableHead>
                  <TableHead>Roles</TableHead>
                  <TableHead>Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {allUsersQ.isLoading ? (
                  <TableRow>
                    <TableCell colSpan={7} className="text-center">Loading...</TableCell>
                  </TableRow>
                ) : rows.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={7} className="text-center">No users found</TableCell>
                  </TableRow>
                ) : (
                  rows.map((u) => (
                    <TableRow key={u._id}>
                      <TableCell>{u.name}</TableCell>
                      <TableCell>{u.email}</TableCell>
                      <TableCell>{u.phone ?? 'N/A'}</TableCell>
                      <TableCell>{u.department ?? 'N/A'}</TableCell>
                      <TableCell>{u.employeeId ?? 'N/A'}</TableCell>
                      <TableCell>
                        <div className="flex flex-wrap gap-1">
                          {getDisplayRoles(u).map((role, idx) => (
                            <span key={idx} className={`capitalize text-xs px-2 py-1 rounded ${getRoleBadgeColor(role)}`}>
                              {role.replace('_', ' ')}
                            </span>
                          ))}
                        </div>
                        {u.isSupervisor && <span className="text-xs text-gray-500 ml-1 block">(Supervisor)</span>}
                      </TableCell>
                      <TableCell>
                        <Button 
                          variant="outline" 
                          size="sm" 
                          onClick={() => openEditUserDialog(u)}
                        >
                          <Pencil className="h-4 w-4" />
                        </Button>
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </div>
        </CardContent>
      </Card>

      {/* Edit User Dialog */}
      <Dialog open={!!editingUser} onOpenChange={(open) => !open && setEditingUser(null)}>
        <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>Edit User</DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="edit-user-name">Name *</Label>
              <Input 
                id="edit-user-name" 
                value={editUserForm.name} 
                onChange={(e) => setEditUserForm({ ...editUserForm, name: e.target.value })} 
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="edit-user-email">Email</Label>
              <Input 
                id="edit-user-email" 
                type="email" 
                value={editingUser?.email || ""} 
                disabled
                className="bg-muted cursor-not-allowed"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="edit-user-phone">Phone *</Label>
              <Input 
                id="edit-user-phone" 
                value={editUserForm.phone} 
                onChange={(e) => setEditUserForm({ ...editUserForm, phone: e.target.value })} 
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="edit-user-roles">Roles * (Select multiple)</Label>
              <div className="space-y-2 border rounded-md p-3 max-h-48 overflow-y-auto">
                {['staff', 'driver', 'transport_officer', 'dgs', 'ddgs', 'ad_transport', 'admin'].map((role) => (
                  <div key={role} className="flex items-center space-x-2">
                    <Checkbox
                      id={`edit-role-${role}`}
                      checked={editUserForm.roles.includes(role)}
                      onCheckedChange={(checked) => {
                        const currentRoles = [...editUserForm.roles];
                        if (checked) {
                          if (!currentRoles.includes(role)) {
                            setEditUserForm({ ...editUserForm, roles: [...currentRoles, role] });
                          }
                        } else {
                          setEditUserForm({ ...editUserForm, roles: currentRoles.filter(r => r !== role) });
                        }
                      }}
                    />
                    <Label htmlFor={`edit-role-${role}`} className="cursor-pointer capitalize">
                      {role.replace('_', ' ')}
                    </Label>
                  </div>
                ))}
              </div>
              {editUserForm.roles.length === 0 && (
                <p className="text-xs text-red-500">Please select at least one role</p>
              )}
            </div>
            <div className="space-y-2">
              <Label htmlFor="edit-user-password">New Password (leave blank to keep current)</Label>
              <Input 
                id="edit-user-password" 
                type="password" 
                value={editUserForm.password} 
                onChange={(e) => setEditUserForm({ ...editUserForm, password: e.target.value })} 
                placeholder="Enter new password"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="edit-user-department">Department {editUserForm.roles.includes('staff') ? '*' : ''}</Label>
              <Select
                value={editUserForm.department}
                onValueChange={(value) => setEditUserForm({ ...editUserForm, department: value })}
              >
                <SelectTrigger id="edit-user-department">
                  <SelectValue placeholder="Select a department" />
                </SelectTrigger>
                <SelectContent>
                  {departmentsQ.data?.map((dept) => (
                    <SelectItem key={dept._id} value={dept.name}>
                      {dept.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="flex items-center space-x-2">
              <Checkbox
                id="edit-user-supervisor"
                checked={editUserForm.isSupervisor}
                onCheckedChange={(checked) => setEditUserForm({ ...editUserForm, isSupervisor: checked === true })}
              />
              <Label htmlFor="edit-user-supervisor" className="cursor-pointer">Is Supervisor</Label>
            </div>
            {(editUserForm.roles.includes('driver') || editUserForm.roles.includes('staff')) && (
              <div className="space-y-2">
                <Label htmlFor="edit-user-employeeId">Employee ID (optional)</Label>
                <Input 
                  id="edit-user-employeeId" 
                  value={editUserForm.employeeId} 
                  onChange={(e) => setEditUserForm({ ...editUserForm, employeeId: e.target.value })} 
                />
              </div>
            )}
            <div className="flex gap-2 justify-end">
              <Button variant="outline" onClick={() => setEditingUser(null)}>Cancel</Button>
              <Button onClick={updateUser}>Update</Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}


