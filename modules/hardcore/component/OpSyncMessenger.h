/* -*- Mode: c++; tab-width: 4; indent-tabs-mode: t; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2011 Opera Software AS.  All rights reserved.
 *
 * This file is part of the Opera web browser.
 * It may not be distributed under any circumstances.
 */

#ifndef MODULES_HARDCORE_COMPONENT_OPSYNCMESSENGER_H
#define MODULES_HARDCORE_COMPONENT_OPSYNCMESSENGER_H

#include "modules/hardcore/component/OpMessenger.h"

#ifdef MESSAGELOOP_RUNSLICE_SUPPORT

/**
 * A special class messaging class designed to perform synchronous
 * requests across the asynchronous messaging interface.
 */
class OpSyncMessenger
	: public OpMessenger
{
public:
	/**
	 * Create a synchronous messenger.
	 *
	 * @param peer A channel to the entity that is to receive the messages. This
	 *        object assumes ownership of the channel. Ownership may be returned
	 *        through TakePeer(). May be NULL, see SendMessage().
	 */
	OpSyncMessenger(OpChannel* peer);
	~OpSyncMessenger();

	/**
	 * Hand over the peer with which SendMessage() will communicate.
	 *
	 * This method should only be called if the object was constructed without
	 * a peer, or if the peer has been taken (see TakePeer()).
	 *
	 * @param peer The channel that is to receive the messages. This method
	 *        transfers ownership of the channel to this object.
	 */
	void GivePeer(OpChannel* peer) { OP_ASSERT(!m_peer); m_peer = peer; }

	/**
	 * Check if this object has a peer
	 *
	 * @return Whether this object has a peer to communicate with
	 */
	bool HasPeer() { return m_peer != NULL; }

	/**
	 * Take the peer from this object.
	 *
	 * @return OpChannel pointer previously given, or NULL if the channel is destroyed or unset.
	 */
	OpChannel* TakePeer();

	/** Restrict response types.
	 *
	 * By default the OpSyncMessenger will accept any message (which is not an
	 * OpStatusMessage) as response to the message that was send by
	 * SendMessage(). If this method is called, only a message of the specified
	 * type(s) will be accepted as response.
	 *
	 * This method must be called before SendMessage() to have any effect. This
	 * method may be called multiple times to add more types to the list of
	 * accepted response types.
	 *
	 * @param type Message type to accept. Any class derived from
	 *        OpTypedMessageBase declares an unsigned member \c Type (e.g.,
	 *        OpLegacyMessage::Type) which can be used as a valid value. See
	 *        also OpTypedMessageBase::VerifyType().
	 *
	 * @return OpStatus::OK on success, OpStatus::ERR_NO_MEMORY on OOM.
	 */
	OP_STATUS AcceptResponse(OpMessageType type);

	/**
	 * Send a message to the recipient.
	 *
	 * This method behaves like OpMessenger::SendMessage, but will not return
	 * until it has received a response or experienced an error.
	 *
	 * If this method returns OpStatus::OK, the received response is available
	 * from GetResponse().
	 *
	 * @param message The message to send.
	 *
	 * @param allow_nesting If true, the currently running component will
	 *        continue to run as normal while waiting for the response. If
	 *        allow_nesting is false, all messages to other channels in the
	 *        component will be blocked for the duration of the call.
	 * @param timeout An optional timeout in milliseconds. If no response is
	 *        received within the alotted time, the operation will abort. A
	 *        timeout argument of zero means that there is no timeout, and that
	 *        the method may (if no response is forthcoming) block forever.
	 *
	 * @note An OpPeerDisconnectedMessage will be generated by the underlying
	 *       message system if the process hosting the remote peer crashes or
	 *       deviates from expected behavior, so there should be no reason to
	 *       utilize timeouts to handle such cases.)
	 *
	 * @return OpStatus::OK on success, OpStatus::ERR_NO_MEMORY on OOM or if peer
	 *         argument to the constructor NULL, OpStatus::ERR_YIELD on timeout,
	 *         OpStatus::ERR_NO_SUCH_RESOURCE if the remote peer was disconnected,
	 *         or an OpStatus error code returned from the remote channel.
	 */
	virtual OP_STATUS SendMessage(OpTypedMessage* message, bool allow_nesting, unsigned int timeout);
	virtual OP_STATUS SendMessage(OpTypedMessage* message, unsigned int flags = SENDMESSAGE_OOM_IF_NULL) { return SendMessage(message, true, 0); }

	/**
	 * Send a message to the recipient.
	 *
	 * This method behaves like OpMessenger::SendMessage, but will not return
	 * until it has received a response or experienced an error.
	 *
	 * If this method returns OpStatus::OK, the received response is available
	 * from GetResponse().
	 *
	 * @param message The message to send.
	 * @param filter Message filter to enable while waiting for a response.
	 * @param timeout An optional timeout in milliseconds. If no response is
	 *        received within the alotted time, the operation will abort.
	 *
	 * @return OpStatus::OK on success, OpStatus::ERR_NO_MEMORY on OOM or if peer
	 *         argument to the constructor NULL, OpStatus::ERR_YIELD on timeout,
	 *         OpStatus::ERR_NO_SUCH_RESOURCE if the remote peer was disconnected,
	 *         or an OpStatus error code returned from the remote channel.
	 */
	virtual OP_STATUS SendMessage(OpTypedMessage* message, OpTypedMessageSelection* filter, unsigned int timeout = 0);

	/**
	 * Retrieve response message received during SendMessage.
	 *
	 * @return OpTypedMessage if SendMessage succeeded, otherwise NULL. The
	 *         message remains owned by OpSyncMessenger.
	 */
	OpTypedMessage* GetResponse();

	/**
	 * Retrieve and take ownership of response message received during SendMessage.
	 *
	 * @return OpTypedMessage if SendMessage succeeded, otherwise NULL.
	 */
	OpTypedMessage* TakeResponse();

	/**
	 * Process incoming messages.
	 *
	 * - If an OpPeerConnectedMessage is received, the message that is requested
	 *   to be sent by SendMessage() is sent to the peer. SendMessage() does not
	 *   send the message to the peer immediately, instead it stores the message
	 *   in m_message and waits for the m_peer to connect and send this
	 *   OpPeerConnectedMessage.
	 * - If an OpStatusMessage containing an error is received, SendMessage()
	 *   will abort, returning the error contained within the message.
	 * - If an OpPeerDisconnectedMessage is received, SendMessage() will abort
	 *   with the error ERR_NO_SUCH_RESOURCE.
	 * - If any other message type is received, it will either be considered the
	 *   response message and SendMessage() will return success, or, if
	 *   AcceptMessage() has been called and the message type is not among those
	 *   deemed acceptable, the message is ignored.
	 *
	 * @param message Message.
	 *
	 * @return OpStatus::OK on success.
	 */
	virtual OP_STATUS ProcessMessage(const OpTypedMessage* message);

	/**
	 * Send delayed timeout message to the channel used by this messenger.
	 *
	 * This is equivalent to calling SendMessage with an equivalent timeout argument.
	 *
	 * @param timeout Milliseconds until the timeout should occur.
	 *
	 * @return OpStatus::OK on success, OpStatus::ERR_NO_MEMORY on OOM or the messenger has no valid
	 *         peer.
	 */
	OP_STATUS SetTimeout(unsigned int timeout);

protected:

	/**
	 * Clear any existing response stored in m_response.
	 */
	void ClearResponse();

	/**
	 * Send and receive message on behalf of the SendMessage()s.
	 *
	 * See SendMessage().
	 *
	 * @param message The message to send.
	 * @param timeout An optional timeout in milliseconds. See SendMessage().
	 * @param flags Flags to pass to OpComponentPlatform::ProcessEvents().
	 *        See OpComponentPlatform::EventFlags.
	 */
	OP_STATUS ExchangeMessages(OpTypedMessage* message, unsigned int timeout,
							   OpComponentPlatform::EventFlags flags = OpComponentPlatform::PROCESS_IPC_MESSAGES);


	/**
	 * Send outgoing message. Expects valid message in m_message.
	 */
	OP_STATUS Send();

	/**
	 * Clone a message.
	 *
	 * @param out_clone Pointer to cloned message.
	 * @param message Message to clone.
	 *
	 * @return OpStatus::OK on success, OpStatus::ERR_NO_MEMORY on failure.
	 */
	OP_STATUS CloneMessage(OpTypedMessage** out_clone, const OpTypedMessage* message);

	/**
	 * Check if a message is acceptable as a response.
	 */
	bool HasAcceptableType(const OpTypedMessage* message);

	/**
	 * Push sync messenger activation record.
	 *
	 * When several sync messengers are on the call stack, nested N levels deep, and the Mth (M < N)
	 * messenger times out, we want to abort all deeper messengers M...N, regardless of their
	 * individual timeout values. The sync messenger activation record stack exists to aid in
	 * discovery of these deeper messengers. See PropagateTimeout().
	 *
	 * This method and PopActivationRecord() should sandwich any call to YieldPlatform().
	 *
	 * @return OpStatus::OK on success, OpStatus::ERR_NO_MEMORY on OOM.
	 */
	OP_STATUS PushActivationRecord();

	/**
	 * Pop sync messenger activation record.
	 *
	 * See PushActivationRecord().
	 */
	void PopActivationRecord();

	/**
	 * Transmit immediate timeout to all active messengers inside our call stack frame.
	 *
	 * @return OpStatus::OK on success, OpStatus::ERR_NO_SUCH_RESOURCE if no activation
	 *         stack could be found, or OpStatus::ERR_NO_MEMORY on OOM.
	 */
	OP_STATUS PropagateTimeout();

	/// The entity we are communicating with.
	OpChannel* m_peer;

	/// The message we are to send.
	OpTypedMessage* m_message;

	/// A copy of the response received.
	OpTypedMessage* m_response;

	/// The status of the transaction.
	OP_STATUS m_status;

	/// A list of message types that will be allowed as a response. An empty list means any type is accepted.
	OpINT32Vector m_acceptable_response_types;
};

#endif // MESSAGELOOP_RUNSLICE_SUPPORT
#endif // MODULES_HARDCORE_COMPONENT_OPSYNCMESSENGER_H