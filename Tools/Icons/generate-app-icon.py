# Generates the SVG layers of AppIcon.icon.
# Usage: python3 Tools/Icons/generate-app-icon.py StayLit/AppIcon.icon
# (icon.json is edited by hand or in Icon Composer; copy the result to KYALauncher/AppIcon.icon too.)
import math, random, sys, os
out = sys.argv[1]
os.makedirs(out + "/Assets", exist_ok=True)
W = 1024
CX, CY = 512, 640              # the star sits on the planet's limb
PCX, PCY, PR = 512, 1480, 820  # planet: top of limb at y=660

def svg(body):
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<svg width="{W}" height="{W}" viewBox="0 0 {W} {W}" xmlns="http://www.w3.org/2000/svg">\n'
            + body + '</svg>\n')

def circle(cx, cy, r):
    return (f"M {cx-r:.2f} {cy:.2f} A {r:.2f} {r:.2f} 0 1 0 {cx+r:.2f} {cy:.2f} "
            f"A {r:.2f} {r:.2f} 0 1 0 {cx-r:.2f} {cy:.2f} Z ")

# Warp streaks: clean tapered rays fanning out from the star
random.seed(7)
streaks = []
n = 17
for i in range(n):
    t = (i + 0.5) / n
    ang = math.radians(192 + t * 156 + random.uniform(-3, 3))
    r0 = random.uniform(190, 300)
    r1 = r0 + random.uniform(120, 300)
    w0, w1 = 1.0, random.uniform(6, 11)
    dx, dy = math.cos(ang), math.sin(ang)
    nx, ny = -dy, dx
    p = [(CX+dx*r0+nx*w0, CY+dy*r0+ny*w0), (CX+dx*r1+nx*w1, CY+dy*r1+ny*w1),
         (CX+dx*r1-nx*w1, CY+dy*r1-ny*w1), (CX+dx*r0-nx*w0, CY+dy*r0-ny*w0)]
    streaks.append("M " + " L ".join(f"{x:.2f} {y:.2f}" for x, y in p) + " Z ")
dots = []
for x, y, r in [(150,170,6),(300,110,4),(700,90,5),(880,210,6),(820,420,4),(190,400,4),(560,200,4),(420,300,3),(960,520,4),(70,560,4),(640,380,3)]:
    dots.append(circle(x, y, r))
open(out + "/Assets/Warp.svg", "w").write(svg(
    f'  <path fill="#FFFFFF" d="{"".join(streaks)}{"".join(dots)}"/>\n'))

open(out + "/Assets/Planet.svg", "w").write(svg(
    f'  <path fill="#0F5FB8" d="{circle(PCX, PCY, PR)}"/>\n'))
rim = circle(PCX, PCY, PR + 10) + circle(PCX, PCY + 12, PR + 1)
open(out + "/Assets/Rim.svg", "w").write(svg(
    f'  <path fill="#BFF3FF" fill-rule="evenodd" d="{rim}"/>\n'))

def spike(cx, cy, rx, ry, w=16):
    # thin four-point flare: tips joined through a narrow waist
    pts = [(cx-rx, cy), (cx-w, cy-w), (cx, cy-ry), (cx+w, cy-w), (cx+rx, cy), (cx+w, cy+w), (cx, cy+ry), (cx-w, cy+w)]
    return "M " + " L ".join(f"{x:.2f} {y:.2f}" for x, y in pts) + " Z "
open(out + "/Assets/Glow.svg", "w").write(svg(
    f'  <path fill="#FFE2A0" d="{circle(CX, CY, 190)}"/>\n'))
open(out + "/Assets/Halo.svg", "w").write(svg(
    f'  <path fill="#FFF0C8" d="{circle(CX, CY, 128)}"/>\n'))
open(out + "/Assets/Star.svg", "w").write(svg(
    f'  <path fill="#FFF1CC" d="{spike(CX, CY, 340, 290)}"/>\n'
    f'  <path fill="#FFFBF0" d="{circle(CX, CY, 82)}"/>\n'))
