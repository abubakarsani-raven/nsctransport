"use client"

import * as React from "react"
import { ChevronLeft, ChevronRight } from "lucide-react"
import { DayPicker } from "react-day-picker"
import { format } from "date-fns"

import { cn } from "@/lib/utils"
import { buttonVariants } from "@/components/ui/button"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"

export type CalendarProps = React.ComponentProps<typeof DayPicker>

function Calendar({
  className,
  classNames,
  showOutsideDays = true,
  ...props
}: CalendarProps) {
  const [month, setMonth] = React.useState<Date>(props.month || new Date())
  
  const currentYear = new Date().getFullYear()
  const years = Array.from({ length: 50 }, (_, i) => currentYear - 25 + i)
  const months = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ]

  const handleMonthChange = (monthIndex: number) => {
    const newDate = new Date(month.getFullYear(), monthIndex, 1)
    setMonth(newDate)
    props.onMonthChange?.(newDate)
  }

  const handleYearChange = (year: number) => {
    const newDate = new Date(year, month.getMonth(), 1)
    setMonth(newDate)
    props.onMonthChange?.(newDate)
  }

  return (
    <DayPicker
      month={month}
      onMonthChange={setMonth}
      showOutsideDays={showOutsideDays}
      className={cn("p-3", className)}
      classNames={{
        months: "flex flex-col sm:flex-row space-y-4 sm:space-x-4 sm:space-y-0",
        month: "space-y-4",
        caption: "flex justify-center pt-1 relative items-center mb-4",
        caption_label: "hidden",
        nav: "hidden",
        nav_button: "hidden",
        nav_button_previous: "hidden",
        nav_button_next: "hidden",
        table: "w-full border-collapse",
        head_row: "flex w-full mb-2",
        head_cell:
          "text-muted-foreground w-10 font-semibold text-xs flex items-center justify-center",
        row: "flex w-full mt-1",
        cell: "h-10 w-10 text-center text-sm p-0 relative [&:has([aria-selected].day-range-end)]:rounded-r-md [&:has([aria-selected].day-outside)]:bg-accent/50 [&:has([aria-selected])]:bg-accent first:[&:has([aria-selected])]:rounded-l-md last:[&:has([aria-selected])]:rounded-r-md focus-within:relative focus-within:z-20",
        day: cn(
          buttonVariants({ variant: "ghost" }),
          "h-10 w-10 p-0 font-normal aria-selected:opacity-100"
        ),
        day_range_end: "day-range-end",
        day_selected:
          "bg-primary text-primary-foreground hover:bg-primary hover:text-primary-foreground focus:bg-primary focus:text-primary-foreground",
        day_today: "bg-accent text-accent-foreground",
        day_outside:
          "day-outside text-muted-foreground opacity-50 aria-selected:bg-accent/50 aria-selected:text-muted-foreground aria-selected:opacity-30",
        day_disabled: "text-muted-foreground opacity-50",
        day_range_middle:
          "aria-selected:bg-accent aria-selected:text-accent-foreground",
        day_hidden: "invisible",
        ...classNames,
      }}
      components={{
        // @ts-ignore - react-day-picker v9 types may not include all component overrides
        Caption: ({ displayMonth }: { displayMonth: Date }) => {
          return (
            <div className="flex items-center justify-center gap-2">
              <button
                type="button"
                onClick={() => {
                  const newDate = new Date(displayMonth.getFullYear(), displayMonth.getMonth() - 1, 1)
                  setMonth(newDate)
                  props.onMonthChange?.(newDate)
                }}
                className={cn(
                  buttonVariants({ variant: "outline" }),
                  "h-7 w-7 bg-transparent p-0 opacity-50 hover:opacity-100"
                )}
              >
                <ChevronLeft className="h-4 w-4" />
              </button>
              
              <div className="flex items-center gap-2">
                <Select
                  value={displayMonth.getMonth().toString()}
                  onValueChange={(value) => handleMonthChange(parseInt(value))}
                >
                  <SelectTrigger className="h-7 w-[120px] text-sm font-medium">
                    <SelectValue>{format(displayMonth, "MMMM")}</SelectValue>
                  </SelectTrigger>
                  <SelectContent>
                    {months.map((monthName, index) => (
                      <SelectItem key={index} value={index.toString()}>
                        {monthName}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>

                <Select
                  value={displayMonth.getFullYear().toString()}
                  onValueChange={(value) => handleYearChange(parseInt(value))}
                >
                  <SelectTrigger className="h-7 w-[90px] text-sm font-medium">
                    <SelectValue>{displayMonth.getFullYear()}</SelectValue>
                  </SelectTrigger>
                  <SelectContent className="max-h-[200px]">
                    {years.map((year) => (
                      <SelectItem key={year} value={year.toString()}>
                        {year}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <button
                type="button"
                onClick={() => {
                  const newDate = new Date(displayMonth.getFullYear(), displayMonth.getMonth() + 1, 1)
                  setMonth(newDate)
                  props.onMonthChange?.(newDate)
                }}
                className={cn(
                  buttonVariants({ variant: "outline" }),
                  "h-7 w-7 bg-transparent p-0 opacity-50 hover:opacity-100"
                )}
              >
                <ChevronRight className="h-4 w-4" />
              </button>
            </div>
          )
        },
        // @ts-ignore - react-day-picker v9 types may not include all component overrides
        IconLeft: () => null,
        // @ts-ignore - react-day-picker v9 types may not include all component overrides
        IconRight: () => null,
      } as any}
      {...props}
    />
  )
}
Calendar.displayName = "Calendar"

export { Calendar }
