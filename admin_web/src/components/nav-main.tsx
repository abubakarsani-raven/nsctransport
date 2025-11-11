"use client"

import Link from "next/link"
import { type LucideIcon, ChevronRight } from "lucide-react"
import { useState, useEffect, useRef } from "react"

import {
  SidebarGroup,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarMenuSub,
  SidebarMenuSubButton,
  SidebarMenuSubItem,
} from "@/components/ui/sidebar"
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from "@/components/ui/collapsible"

export interface NavItem {
  title: string
  url?: string
  icon?: LucideIcon
  isActive?: boolean
  items?: NavItem[]
}

export function NavMain({
  items,
}: {
  items: NavItem[]
}) {
  // Auto-expand items that are active
  const getInitialOpenItems = () => {
    const open = new Set<string>()
    items.forEach((item) => {
      if (item.items && item.items.length > 0 && item.isActive) {
        open.add(item.title)
      }
    })
    return open
  }

  const [openItems, setOpenItems] = useState<Set<string>>(getInitialOpenItems())
  const initializedRef = useRef(false)

  // Update open items when active state changes - check if any item has active sub-items
  useEffect(() => {
    if (!initializedRef.current) {
      initializedRef.current = true
      return
    }
    
    setOpenItems(prev => {
      const newSet = new Set(prev)
      items.forEach((item) => {
        if (item.items && item.items.length > 0) {
          const hasActiveSubItem = item.items.some(subItem => subItem.isActive)
          if (hasActiveSubItem) {
            newSet.add(item.title)
          }
        }
      })
      return newSet
    })
  }, [items])

  const toggleItem = (title: string) => {
    const newOpenItems = new Set(openItems)
    if (newOpenItems.has(title)) {
      newOpenItems.delete(title)
    } else {
      newOpenItems.add(title)
    }
    setOpenItems(newOpenItems)
  }

  return (
    <SidebarGroup>
      <SidebarMenu>
        {items.map((item) => {
          if (item.items && item.items.length > 0) {
            const isOpen = openItems.has(item.title)
            return (
              <SidebarMenuItem key={item.title}>
                <Collapsible
                  open={isOpen}
                  onOpenChange={() => toggleItem(item.title)}
                >
                  <CollapsibleTrigger asChild>
                    <SidebarMenuButton tooltip={item.title} isActive={item.isActive}>
                      {item.icon && <item.icon />}
                      <span>{item.title}</span>
                      <ChevronRight
                        className={`ml-auto transition-transform duration-200 ${
                          isOpen ? "rotate-90" : ""
                        }`}
                      />
                    </SidebarMenuButton>
                  </CollapsibleTrigger>
                  <CollapsibleContent>
                    <SidebarMenuSub>
                      {item.items.map((subItem) => (
                        <SidebarMenuSubItem key={subItem.title}>
                          <SidebarMenuSubButton asChild isActive={subItem.isActive}>
                            <Link href={subItem.url || "#"}>
                              {subItem.icon && <subItem.icon />}
                              <span>{subItem.title}</span>
                            </Link>
                          </SidebarMenuSubButton>
                        </SidebarMenuSubItem>
                      ))}
                    </SidebarMenuSub>
                  </CollapsibleContent>
                </Collapsible>
              </SidebarMenuItem>
            )
          }

          return (
            <SidebarMenuItem key={item.title}>
              <SidebarMenuButton asChild tooltip={item.title} isActive={item.isActive}>
                <Link href={item.url || "#"}>
                  {item.icon && <item.icon />}
                  <span>{item.title}</span>
                </Link>
              </SidebarMenuButton>
            </SidebarMenuItem>
          )
        })}
      </SidebarMenu>
    </SidebarGroup>
  )
}
