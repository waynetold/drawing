function [out1,out2,savepts] = eqdconic(mstruct,in1,in2,object,direction,savepts)

%EQDCONIC  Equidistant Conic Projection
%
%  In this projection, scale is true along each meridian and the one or
%  two selected standard parallels.  Scale is constant along any
%  parallel.  This projection is free of distortion along the two
%  standard parallels.  Distortion is constant along any other parallel.
%  This projection provides a compromise in distortion between conformal
%  and equal area conic projections, of which it is neither.
%
%  In a rudimentary form, this projection dates back to Claudius Ptolemy,
%  about A.D. 100.  Improvements were developed by Johannes Ruysch in
%  1508, Gerardus Mercator in the late 16th century, and Nicolas de
%  l'Isle in 1745.  It is also known as the Simple Conic or Conic
%  projection.  The cone of projection has interesting limiting forms.
%  If a pole is selected as a single standard parallel, the cone is a
%  plane, and an Equidistant Azimuthal projection results.  If the
%  Equator is so chosen, the cone becomes a cylinder and a Plate
%  Carree projection results.  If two parallels equidistant from
%  the Equator are chosen as the standard parallels, an Equidistant
%  Cylindrical projection results.

%  Copyright 1996-1998 by Systems Planning and Analysis, Inc. and The MathWorks, Inc.
% $Revision: 1.6 $
%  Written by:  E. Byrns, E. Brown


if nargin == 1                  %  Set the default structure entries
      if length(mstruct.mapparallels) ~= 2
		mstruct.mapparallels = angledim([15 75],'degrees',mstruct.angleunits); % 1/6th and 5/6th of the northern hemisphere
      end
      mstruct.nparallels   = 2;
	  mstruct.trimlat = angledim([ -90  90],'degrees',mstruct.angleunits);
      mstruct.trimlon = angledim([-135 135],'degrees',mstruct.angleunits);
	  mstruct.fixedorient  = [];
	  out1 = mstruct;          return
elseif nargin ~= 5 & nargin ~= 6
      error('Incorrect number of arguments')
end

%  Extract the necessary projection data and convert to radians

units  = mstruct.angleunits;
aspect = mstruct.aspect;
radius = rsphere('rectifying',mstruct.geoid);
parallels = angledim(mstruct.mapparallels,units,'radians');
origin    = angledim(mstruct.origin,units,'radians');
trimlat   = angledim(mstruct.flatlimit,units,'radians');
trimlon   = angledim(mstruct.flonlimit,units,'radians');
scalefactor = mstruct.scalefactor;
falseeasting = mstruct.falseeasting;
falsenorthing = mstruct.falsenorthing;

%  Eliminate singularities in transformations with 0 parallel.

epsilon = epsm('radians');
indx = find(abs(parallels) <= epsilon);
if ~isempty(indx);   parallels(indx) = epsilon;    end

%  Compute projection parameters

rectifies  = geod2rec(parallels,mstruct.geoid,'radians');
a = mstruct.geoid(1);    e = mstruct.geoid(2);


den1 = (1 + e*sin(parallels(1))) * (1 - e*sin(parallels(1)));
m1   = cos(parallels(1)) / sqrt(den1);

if length(parallels) == 1 | abs(diff(parallels)) < epsilon
    n = sin(parallels(1));
else
    if diff(abs(parallels)) < epsilon
         parallels(2) = parallels(2) - sign(parallels(2))*epsilon;
    end
    den2 = (1 + e*sin(parallels(2))) * (1 - e*sin(parallels(2)));
    m2   = cos(parallels(2)) / sqrt(den2);
    n    = a * (m1 - m2) / (radius * (rectifies(2)-rectifies(1)) );
end


G     = m1/n + radius*rectifies(1)/a;
rho0  = a*G;


%  Adjust the origin latitude to the auxiliary sphere

origin(1) = geod2rec(origin(1),mstruct.geoid,'radians');
trimlat   = geod2rec(trimlat  ,mstruct.geoid,'radians');
%parallels done above


switch direction
case 'forward'

     lat  = angledim(in1,units,'radians');
     lat  = geod2rec(lat,mstruct.geoid,'radians');
     long = angledim(in2,units,'radians');

     [lat,long] = rotatem(lat,long,origin,direction);   %  Rotate to new origin
     [lat,long,clipped] = clipdata(lat,long,object);    %  Clip at the date line
     [lat,long,trimmed] = trimdata(lat,trimlat,long,trimlon,object);

%  Construct the structure of altered points

     savepts.trimmed = trimmed;
     savepts.clipped = clipped;

%  Projection transformation

     theta = n*long;
     rho   = a*G - radius*lat;
     x     = rho .* sin(theta);
     y     = rho0 - rho .* cos(theta);

%  Apply scale factor, false easting, northing

	x = x*scalefactor+falseeasting;
	y = y*scalefactor+falsenorthing;

%  Set the output variables

     switch  aspect
	    case 'normal',         out1 = x;      out2 = y;
	    case 'transverse',	   out1 = y;      out2 = -x;
        otherwise,             error('Unrecognized aspect string')
     end


case 'inverse'


     switch  aspect
	    case 'normal',         x = in1;    y = in2;
	    case 'transverse',	   x = -in2;   y = in1;
        otherwise,             error('Unrecognized aspect string')
     end
 
%  Apply scale factor, false easting, northing

	x = (x-falseeasting)/scalefactor;
	y = (y-falsenorthing)/scalefactor;

% Inverse projection

     rho  = sign(n)*sqrt(x.^2 + (rho0-y).^2);
     theta = atan2(sign(n)*x, sign(n)*(rho0-y));

     lat = (a*G - rho)/radius;
     long = theta/n;

%  Undo trims and clips

     [lat,long] = undotrim(lat,long,savepts.trimmed,object);
     [lat,long] = undoclip(lat,long,savepts.clipped,object);

%  Rotate to Greenwich and transform to desired units

     [lat,long] = rotatem(lat,long,origin,direction);
     lat        = rec2geod(lat,mstruct.geoid,'radians');

     out1 = angledim(lat, 'radians', units);
     out2 = angledim(long,'radians', units);

otherwise
     error('Unrecognized direction string')
end

%  Some operations on NaNs produce NaN + NaNi.  However operations
%  outside the map may product complex results and we don't want
%  to destroy this indicator.

if isieee == 1
   indx = find(isnan(out1) | isnan(out2));
   out1(indx) = NaN;   out2(indx) = NaN;
end
