import * as React from "react"

const MOBILE_BREAKPOINT = 768

export function useIsMobile() {
  // Always start with false to match SSR
  const [isMobile, setIsMobile] = React.useState<boolean>(false)

  React.useEffect(() => {
    // Only run on client side
    const checkMobile = () => {
      setIsMobile(window.innerWidth < MOBILE_BREAKPOINT)
    }
    
    // Set initial value
    checkMobile()
    
    // Listen for changes
    const mql = window.matchMedia(`(max-width: ${MOBILE_BREAKPOINT - 1}px)`)
    mql.addEventListener("change", checkMobile)
    
    return () => mql.removeEventListener("change", checkMobile)
  }, [])

  return isMobile
}
