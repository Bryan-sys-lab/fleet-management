import { clerkMiddleware, createRouteMatcher } from "@clerk/nextjs/server";

const isProtectedRoute = createRouteMatcher([
  "/dashboard(.*)",
  "/users(.*)",
  "/tenants(.*)",
  "/training(.*)",
  "/fuel(.*)",
  "/inspections(.*)",
  "/accidents(.*)",
  "/vehicles(.*)",
  "/settings(.*)",
  "/privacy(.*)",
]);

export default clerkMiddleware((auth, req) => {
  if (isProtectedRoute(req)) {
    auth().protect();
  }
});

export const config = {
  matcher: ["/((?!.*\\..*|_next).*)", "/", "/(api|trpc)(.*)"],
};
