%READ_BF_SOCKET Reads in a file of beamforming feedback logs.
%   This version uses the *C* version of read_bfee, compiled with
%   MATLAB's MEX utility.
%
% (c) 2008-2011 Daniel Halperin <dhalperi@cs.washington.edu>
%
%   Modified by Renjie Zhang, Bingxian Lu.
%   Email: bingxian.lu@gmail.com

function read_bf_socket()

while 1
%% Build a TCP Server and wait for connection
% Using '0.0.0.0' as the IP address means that the server will accept the first
% machine that tries to connect. To restrict the connections that will be accepted,
% replace '0.0.0.0' with the address of the client in the code for Session 1.
    t = tcpip('0.0.0.0', 8090, 'NetworkRole', 'server');
    t.InputBufferSize = 1024;
    t.Timeout = 15;
    fopen(t); % 一旦fopen函数被调用，MATLAB进程就会被阻塞，直到收到连接或者 Ctrl+C强制结束

%% Set plot parameters
    clf;
    axis([1,30,-10,30]);
    t1=0;
    m1=zeros(30,1);

    p = plot(t1,m1,'EraseMode','Xor','MarkerSize',5);
%%  Starting in R2014b, the EraseMode property has been removed from all graphics objects. 
%%  https://mathworks.com/help/matlab/graphics_transition/how-do-i-replace-the-erasemode-property.html
%%  For Matlab version > R2014a
%%  p = plot(t1,m1,'MarkerSize',5);

    xlabel('subcarrier index');
    ylabel('SNR (dB)');

%% Initialize variables
    ret = cell(1,1);
    index = -1;                     % The index of the plots which need shadowing
    broken_perm = 0;                % Flag marking whether we've encountered a broken CSI yet
    triangle = [1 3 6];             % What perm should sum to for 1,2,3 antennas

%% Process all entries in socket
    % Need 3 bytes -- 2 byte size field and 1 byte code
    while 1
        % Read size and code from the received packets
        s = warning('error', 'instrument:fread:unsuccessfulRead');
        try
            field_len = fread(t, 1, 'uint16');  % size
        catch
            warning(s);
            disp('Timeout, please restart the client and connect again.');
            break;
        end

        code = fread(t,1);    
        % If unhandled code, skip (seek over) the record and continue
        if (code == 187) % get beamforming or phy data
            bytes = fread(t, field_len-1, 'uint8');
            bytes = uint8(bytes);
            if (length(bytes) ~= field_len-1)
                fclose(t);
                return;
            end
        else if field_len <= t.InputBufferSize  % skip all other info
            fread(t, field_len-1, 'uint8');
            continue;
            else
                continue;
            end
        end

        if (code == 187) % (tips: 187 = hex2dec('bb')) Beamforming matrix -- output a record
            ret{1} = read_bfee(bytes);
        
            perm = ret{1}.perm;
            Nrx = ret{1}.Nrx;
            if Nrx == 1 % No permuting needed for only 1 antenna
                continue;
            end
            if sum(perm) ~= triangle(Nrx) % matrix does not contain default values
                if broken_perm == 0
                    broken_perm = 1;
                    fprintf('WARN ONCE: Found CSI (%s) with Nrx=%d and invalid perm=[%s]\n', filename, Nrx, int2str(perm));
                end
            else
                ret{1}.csi(:,perm(1:Nrx),:) = ret{1}.csi(:,1:Nrx,:);  % Nrx是收端天线数目
            end
        end
    
        index = mod(index+1, 10);
        % index取值是0-9
        csi = get_scaled_csi(ret{1});%CSI data
	%You can use the CSI data here.

	%This plot will show graphics about recent 10 csi packets
        set(p(index*3 + 1),'XData', [1:30], 'YData', db(abs(squeeze(csi(1,1,:)).')), 'color', 'b', 'linestyle', '-');
        set(p(index*3 + 2),'XData', [1:30], 'YData', db(abs(squeeze(csi(1,2,:)).')), 'color', 'g', 'linestyle', '-');
        set(p(index*3 + 3),'XData', [1:30], 'YData', db(abs(squeeze(csi(1,3,:)).')), 'color', 'r', 'linestyle', '-');

        drawnow;
 
        ret{1} = [];
    end
%% Close file
    fclose(t);
    delete(t);
end

end