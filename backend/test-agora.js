import pkg from 'agora-access-token';
const { RtcTokenBuilder, RtcRole } = pkg;
import dotenv from 'dotenv';
dotenv.config();

const appId = '3ce923c6b5cb422bae0674cc9ddf11f0';
const appCertificate = '4555118b8d6242d2b21e5ef9c2ad021e';
const channelName = 'test_channel';
const uid = 0;
const role = RtcRole.PUBLISHER;
const expirationTimeInSeconds = 3600;
const currentTimestamp = Math.floor(Date.now() / 1000);
const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

try {
    const token = RtcTokenBuilder.buildTokenWithUid(
        appId,
        appCertificate,
        channelName,
        uid,
        role,
        privilegeExpiredTs
    );
    console.log('Token generated successfully:', token);
} catch (error) {
    console.error('Error generating token:', error);
}
