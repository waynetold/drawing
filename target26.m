function targets = target26(r)
cube = [ ...
1 1 1; ...
-1 1 1; ...
-1 -1 1; ...
1 -1 1; ...
1 1 -1; ...
-1 1 -1; ...
-1 -1 -1; ...
1 -1 -1];
axes = [ ...
1 0 0; ...
-1 0 0; ...
0 1 0; ...
0 -1 0; ...
0 0 1; ...
0 0 -1];
edges = [ ...
1 1 0; ...
-1 1 0; ...
-1 -1 0; ...
1 -1 0; ...
1 0 1; ...
-1 0 1; ...
-1 0 -1; ...
1 0 -1; ...
0 1 1; ...
0 1 -1; ...
0 -1 -1; ...
0 -1 1];
targets = [cube; axes; edges];
targets = bsxfun(@rdivide,targets,sqrt(sum(targets.^2,2)));
targets = targets .* r;
end