function [canA, canB, canR, canCoeff, canLag] = drawingCanonical(drawingSnips, drawingKin, drawingRate, drawingRateLag, drawing)
nTrials = cellfun(@(x) size(x.time,1), drawingSnips);
fold = arrayfun(@(x) crossvalind('Kfold',x,5), nTrials, 'UniformOutput', false);

basis = drawingBasis(drawingSnips, drawingKin);
canLag = cell(length(basis),5);
canA = cell(size(basis));
canB = cell(size(basis));
canR = cell(size(basis));

for k=1:5
    for day=1:length(basis)
        sel = drawingSnips{day}.is_ellipse | ~drawingSnips{day}.is_illusion;
        sel = sel & fold{day}~=k;
        bday = structfun(@(x) x(sel,:), basis{day}, 'UniformOutput', false);
        dday = structfun(@(x) x(sel,:), drawingRate{day}, 'UniformOutput', false);
        X = unravel(bday);
        Y = unravel(dday);
        mask = sum(isnan(X),2)+sum(isnan(Y),2)==0;
        [A,B,r] = canoncorr(X(mask,:),Y(mask,:));

        % Flip correlates so they contain generally positive coefficients
        T = diag(sign(var(Y)*B));
        A = A*T;
        B = B*T;
        r = T'*diag(r)*T;

        canA{day} = A;
        canB{day} = B;
        canR{day} = r;
    end

    % Rearrange the correlates so that they correspond to the same elements
    % each day
    quality = cellfun(@(X) mean(X(:)), canR);
    best = quality==max(quality);
    for day=1:length(basis)
        [A,T] = rotatefactors(canA{day},'Method','procrustes','Target',canA{best},'Type','orthogonal');
        % We just want to do reordering and changes of sign
        for col=1:size(T,2)
            mask = abs(T(:,col))<max(abs(T(:,col)));
            T(mask,col) = 0;
        end
        T = sign(T);
        canA{day} = canA{day}*T;
        canB{day} = canB{day}*T;
        canR{day} = T'*canR{day}*T;
    end

%     % Rotate the latent variables to match the mean
%     meanCanA = canA{best};%mean(cell2mat(shiftdim(canA,-2)),3);
%     for day=1:length(basis)
%         [A,T] = rotatefactors(canA{day},'Method','procrustes','Target',meanCanA,'Type','orthogonal');
%         canA{day} = canA{day}*T;
%         canB{day} = canB{day}*T;
%         canR{day} = T'*canR{day}*T;
%     end
    
    % Recompute latent variables with new coefficients
    canCoeff = cell(size(canB));
    for day=1:length(basis)
        B = pinv(canB{day});
        canCoeff{day} = struct();
        fields = fieldnames(drawingRate{day});
        for unit=1:size(B,2)
            canCoeff{day}.(fields{unit}) = B(:,unit)';
        end
    end
    
    testSnips = cell(size(drawingSnips));
    testRate = cell(size(drawingRate));
    testRateLag = cell(size(drawingRate));
    for day=1:length(basis)
        sel = drawingSnips{day}.is_ellipse | ~drawingSnips{day}.is_illusion;
        sel = sel & fold{day}==k;
        testSnips{day} = structfun(@(x) x(sel,:), drawingSnips{day}, 'UniformOutput', false);
        testRate{day} = structfun(@(x) x(sel,:), drawingRate{day}, 'UniformOutput', false);
        testRateLag{day} = structfun(@(x) x(sel,:), drawingRateLag{day}, 'UniformOutput', false);
    end
    canDrawing = projectDown(canCoeff, testRate);
    canDrawingLag = projectDown(canCoeff, testRateLag);
    canLag(:,k) = canonicalLags(testSnips, drawing, canDrawing, canDrawingLag);
end

