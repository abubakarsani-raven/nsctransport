"use client"

import * as React from "react"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"

interface DatePickerProps {
  date?: Date
  onDateChange: (date: Date | undefined) => void
  placeholder?: string
  disabled?: boolean
}

const months = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December"
]

// Get days in month - correctly handles leap years for February
// Using day 0 of next month returns the last day of current month
const getDaysInMonth = (year: number, month: number): number => {
  return new Date(year, month + 1, 0).getDate()
}

// Check if a year is a leap year
const isLeapYear = (year: number): boolean => {
  return (year % 4 === 0 && year % 100 !== 0) || (year % 400 === 0)
}

export function DatePicker({ date, onDateChange, placeholder, disabled }: DatePickerProps) {
  const currentDate = date || new Date()
  const [selectedYear, setSelectedYear] = React.useState<number>(currentDate.getFullYear())
  const [selectedMonth, setSelectedMonth] = React.useState<number>(currentDate.getMonth())
  const [selectedDay, setSelectedDay] = React.useState<number>(date ? currentDate.getDate() : 1)

  // Update local state when external date changes
  React.useEffect(() => {
    if (date) {
      setSelectedYear(date.getFullYear())
      setSelectedMonth(date.getMonth())
      setSelectedDay(date.getDate())
    }
  }, [date])

  const currentYear = new Date().getFullYear()
  const years = Array.from({ length: 100 }, (_, i) => currentYear - 50 + i)
  const daysInMonth = getDaysInMonth(selectedYear, selectedMonth)
  const days = Array.from({ length: daysInMonth }, (_, i) => i + 1)

  const handleDateChange = (year: number, month: number, day: number) => {
    const newDate = new Date(year, month, day)
    // Set time to start of day to avoid timezone issues
    newDate.setHours(0, 0, 0, 0)
    onDateChange(newDate)
  }

  const handleYearChange = (year: number) => {
    setSelectedYear(year)
    // Adjust day if it's invalid for the new year (e.g., Feb 29 in non-leap year)
    // getDaysInMonth automatically handles leap years
    const maxDay = getDaysInMonth(year, selectedMonth)
    const adjustedDay = Math.min(selectedDay, maxDay)
    setSelectedDay(adjustedDay)
    handleDateChange(year, selectedMonth, adjustedDay)
  }

  const handleMonthChange = (month: number) => {
    setSelectedMonth(month)
    // Adjust day if it's invalid for the new month (e.g., day 31 in February)
    // getDaysInMonth automatically handles leap years for February
    const maxDay = getDaysInMonth(selectedYear, month)
    const adjustedDay = Math.min(selectedDay, maxDay)
    setSelectedDay(adjustedDay)
    handleDateChange(selectedYear, month, adjustedDay)
  }

  const handleDayChange = (day: number) => {
    setSelectedDay(day)
    handleDateChange(selectedYear, selectedMonth, day)
  }

  return (
    <div className="flex gap-2 w-full">
        <Select
          value={selectedDay.toString()}
          onValueChange={(value) => handleDayChange(parseInt(value))}
          disabled={disabled}
        >
          <SelectTrigger className="w-full">
            <SelectValue placeholder="Day" />
          </SelectTrigger>
          <SelectContent className="max-h-[200px]">
            {days.map((day) => (
              <SelectItem key={day} value={day.toString()}>
                {day}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>

        <Select
          value={selectedMonth.toString()}
          onValueChange={(value) => handleMonthChange(parseInt(value))}
          disabled={disabled}
        >
          <SelectTrigger className="w-full">
            <SelectValue placeholder="Month" />
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
          value={selectedYear.toString()}
          onValueChange={(value) => handleYearChange(parseInt(value))}
          disabled={disabled}
        >
          <SelectTrigger className="w-full">
            <SelectValue placeholder="Year" />
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
  )
}
