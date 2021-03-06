
function [Pmusics] = spotfi(csi_trace,...
 frequency, sub_freq_delta, antenna_distance)
    
    num_packets = length(csi_trace);
	num_packets = 20;

	Pmusics = cell(num_packets, 1);
    for packet_index = 1:num_packets
        csi_entry = csi_trace{packet_index};
        csi = get_scaled_csi(csi_entry);
        csi = csi(1, :, :);
        % Remove the single element dimension
        csi = squeeze(csi);  % 3*30
		
		% csi = csi([1 3 2], :);  % 将天线2和天线3数据进行置换
        
		% Sanitize ToFs with Algorithm 1
		sanitized_csi = spotfi_algorithm_1(csi, sub_freq_delta); % 3*30
	
        % Acquire smoothed CSI matrix
		% smoothed_sanitized_csi = smooth_csi(sanitized_csi);
		smoothed_sanitized_csi = smooth_csi_light(sanitized_csi);

        [Pmusics{packet_index}] = aoa_tof_music(...
                smoothed_sanitized_csi, antenna_distance, frequency, sub_freq_delta);
        fprintf('%d\n',packet_index);
    end
end