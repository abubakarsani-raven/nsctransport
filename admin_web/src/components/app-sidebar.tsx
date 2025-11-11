"use client"

import * as React from "react"
import {
  LayoutDashboard,
  FileText,
  Car,
  Users,
  Building2,
  MapPin,
  Building,
  Truck,
  Package,
} from "lucide-react"
import { usePathname } from "next/navigation"

import { NavMain, type NavItem } from "@/components/nav-main"
import { NavUser } from "@/components/nav-user"
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarRail,
} from "@/components/ui/sidebar"
import { useAuth } from "@/hooks/useAuth"

export function AppSidebar({ ...props }: React.ComponentProps<typeof Sidebar>) {
  const pathname = usePathname()
  const { user } = useAuth()

  const navMain: NavItem[] = [
    {
      title: "Dashboard",
      url: "/",
      icon: LayoutDashboard,
      isActive: pathname === "/",
    },
    {
      title: "ICT Requests",
      url: "/ict-requests",
      icon: FileText,
      isActive: pathname === "/ict-requests",
    },
    {
      title: "Store Requests",
      url: "/store-requests",
      icon: Package,
      isActive: pathname === "/store-requests",
    },
    {
      title: "Transport",
      icon: Truck,
      isActive: pathname.startsWith("/transport"),
      items: [
        {
          title: "Transport Requests",
          url: "/transport/requests",
          isActive: pathname === "/transport/requests",
        },
        {
          title: "Vehicles",
          url: "/transport/vehicles",
          icon: Car,
          isActive: pathname === "/transport/vehicles" || pathname.startsWith("/transport/vehicles/"),
        },
        {
          title: "Tracking",
          url: "/transport/tracking",
          icon: MapPin,
          isActive: pathname === "/transport/tracking",
        },
      ],
    },
    {
      title: "Users",
      url: "/users",
      icon: Users,
      isActive: pathname === "/users",
    },
    {
      title: "Offices",
      url: "/offices",
      icon: Building2,
      isActive: pathname === "/offices",
    },
    {
      title: "Departments",
      url: "/departments",
      icon: Building,
      isActive: pathname === "/departments",
    },
  ]

  return (
    <Sidebar collapsible="icon" {...props}>
      <SidebarHeader>
        <div className="flex items-center gap-2 px-2 py-4 group-data-[collapsible=icon]:justify-center group-data-[collapsible=icon]:gap-0 group-data-[collapsible=icon]:px-0">
          <div className="flex aspect-square size-8 shrink-0 items-center justify-center rounded-lg bg-sidebar-primary text-sidebar-primary-foreground">
            <Car className="size-4" />
          </div>
          <div className="grid flex-1 text-left text-sm leading-tight group-data-[collapsible=icon]:hidden">
            <span className="truncate font-semibold">Admin Panel</span>
            <span className="truncate text-xs">Transport Management</span>
          </div>
        </div>
      </SidebarHeader>
      <SidebarContent>
        <NavMain items={navMain} />
      </SidebarContent>
      <SidebarFooter>
        <NavUser user={user ? { name: user.name, email: user.email, avatar: "" } : { name: "Admin", email: "", avatar: "" }} />
      </SidebarFooter>
      <SidebarRail />
    </Sidebar>
  )
}
